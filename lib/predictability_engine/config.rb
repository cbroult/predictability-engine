# frozen_string_literal: true

require 'yaml'

module PredictabilityEngine
  # Configuration management for the predictability engine.
  class Config
    CONFIG_FILE = '.predictability_engine.yml'

    # Single source of truth: config key → JIRA_ env var suffix.
    JIRA_FIELDS = {
      site: 'SITE', email: 'EMAIL', token: 'API_TOKEN', project: 'PROJECT',
      context_path: 'CONTEXT_PATH', auth_mode: 'AUTH_MODE',
      bearer_token: 'BEARER_TOKEN', auth_cookie: 'AUTH_COOKIE',
      password: 'PASSWORD', totp_secret: 'TOTP_SECRET',
      mfa_login_url: 'MFA_LOGIN_URL', mfa_token_field: 'MFA_TOKEN_FIELD',
      idp_login_url: 'IDP_LOGIN_URL', idp_callback_port: 'IDP_CALLBACK_PORT'
    }.freeze
    private_constant :JIRA_FIELDS

    def self.jira(profile_name = nil)
      load_jira_config(profile_name)
    end

    def self.jira_client(profile = nil)
      require 'jira-ruby'
      instrument_jira_http! unless ::JIRA::HttpClient.ancestors.include?(JiraHttpLogger)
      config = jira(profile)
      validate_jira!(config)
      origin, derived_path = split_jira_site(config[:site])
      base = { site: origin, context_path: config[:context_path] || derived_path, default_headers: {} }
      auth = JiraAuth.build(config)
      client = ::JIRA::Client.new(auth.jira_options(base))
      auth.post_init(client)
      client
    end

    # Splits a full Jira site URL (e.g. "https://host/jira") into the origin
    # ("https://host") and context path ("/jira") that jira-ruby expects.
    # This avoids 301/302 redirect errors when the server requires the path.
    def self.split_jira_site(site_url)
      uri = URI.parse(site_url.to_s.chomp('/'))
      port_suffix = [80, 443].include?(uri.port) ? '' : ":#{uri.port}"
      origin = "#{uri.scheme}://#{uri.host}#{port_suffix}"
      [origin, uri.path]
    end
    private_class_method :split_jira_site

    # Prepended to JIRA::HttpClient to trace every HTTP call at DEBUG level.
    # SemanticLogger evaluates blocks only when debug is active → zero overhead at
    # INFO or higher.
    module JiraHttpLogger
      def make_request(http_method, url, body = '', headers = {})
        log = SemanticLogger['JIRA::HTTP']
        log.debug { "→ #{http_method.upcase} #{url}" }
        result = super
        log.debug { "← #{result.code} #{result.message}" }
        result
      rescue StandardError => e
        SemanticLogger['JIRA::HTTP'].debug { "✗ #{http_method.upcase} #{url} (#{e.class}: #{e.message})" }
        raise
      end
    end
    private_constant :JiraHttpLogger

    def self.instrument_jira_http!
      ::JIRA::HttpClient.prepend(JiraHttpLogger)
    end
    private_class_method :instrument_jira_http!

    def self.validate_jira!(config)
      raise_missing(config, :site)
      case config[:auth_mode].to_s
      when 'bearer'
        raise_missing(config, :bearer_token)
      when 'cookie'
        raise_missing(config, :auth_cookie)
      when 'mfa_api'
        %i[email password totp_secret mfa_login_url].each { |k| raise_missing(config, k) }
      when 'mfa_browser'
        raise_missing(config, :idp_login_url)
      else
        raise_missing(config, :email)
        raise_missing(config, :token)
      end
    end

    def self.raise_missing(config, key)
      return if config[key]

      env_suffix = JIRA_FIELDS[key]
      env_var = env_suffix ? "JIRA_#{env_suffix}" : "JIRA_#{key.to_s.upcase}"
      raise Error, "Jira #{key} not configured (use #{env_var} env var or credentials file)"
    end
    private_class_method :raise_missing

    def self.load_jira_config(profile_name = nil)
      profile_name ||= default_profile_name
      global = load_global_jira_config
      local = load_local_jira_config

      config = load_profile(profile_name, global, local) if profile_name
      config || fallback_config(global, local)
    end

    def self.default_profile_name
      ENV.fetch('JIRA_PROFILE', nil) || ENV.fetch('JIRA_PROJECT', nil)
    end

    def self.fallback_config(global, local)
      JIRA_FIELDS.transform_values { |env_key| jira_val(env_key, global, local) }
    end

    def self.jira_val(name, global, local)
      key = name.downcase.to_sym
      ENV.fetch("JIRA_#{name}", nil) || local[key] || global[key]
    end

    def self.jira_credentials_file
      File.expand_path('~/.config/jira/jira_credentials.yml')
    end

    def self.load_global_jira_config
      load_jira_file(jira_credentials_file, global: true)
    end

    def self.load_local_jira_config
      load_jira_file(CONFIG_FILE, global: false)
    end

    def self.load_jira_file(path, global: true)
      raw = File.exist?(path) ? YAML.load_file(path) : {}
      raw ||= {}
      config = global ? (raw['jira'] || raw) : raw.fetch('jira', {})
      extract_fields(config).merge(profiles: config.fetch('profiles', {}))
    end

    def self.load_profile(name, global, local)
      profile = global[:profiles][name.to_s] || local[:profiles][name.to_s] || {}
      return if profile.empty?

      extract_fields(profile)
    end

    def self.extract_fields(hash)
      JIRA_FIELDS.keys.to_h { |key| [key, hash[key.to_s]] }
    end
    private_class_method :extract_fields

    private_class_method :load_jira_config, :load_global_jira_config,
                         :load_local_jira_config, :load_profile, :default_profile_name,
                         :fallback_config, :load_jira_file, :jira_val
  end
end
