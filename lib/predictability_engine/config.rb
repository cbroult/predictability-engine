# frozen_string_literal: true

require 'yaml'

module PredictabilityEngine
  # Configuration management for the predictability engine.
  class Config
    CONFIG_FILE = '.predictability_engine.yml'

    def self.jira(profile_name = nil)
      load_jira_config(profile_name)
    end

    def self.jira_client(profile = nil)
      require 'jira-ruby'
      instrument_jira_http! unless ::JIRA::HttpClient.ancestors.include?(JiraHttpLogger)
      config = jira(profile)
      validate_jira!(config)
      origin, context_path = split_jira_site(config[:site])
      options = {
        username: config[:email], password: config[:token],
        site: origin, context_path: context_path, auth_type: :basic
      }
      ::JIRA::Client.new(options)
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
      %i[site email token].each do |key|
        next if config[key]

        name = key.to_s.capitalize
        raise Error, "Jira #{name} not configured (use JIRA_#{name.upcase} env var or credentials file)"
      end
    end

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
      {
        site: jira_val('SITE', global, local),
        email: jira_val('EMAIL', global, local),
        token: jira_val('API_TOKEN', global, local),
        project: jira_val('PROJECT', global, local)
      }
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
      { site: config['site'], email: config['email'], token: config['token'],
        project: config['project'], profiles: config.fetch('profiles', {}) }
    end

    def self.load_profile(name, global, local)
      profile = global[:profiles][name.to_s] || local[:profiles][name.to_s] || {}
      return if profile.empty?

      {
        site: profile['site'],
        email: profile['email'],
        token: profile['token'],
        project: profile['project']
      }
    end

    private_class_method :load_jira_config, :load_global_jira_config,
                         :load_local_jira_config, :load_profile, :default_profile_name,
                         :fallback_config, :load_jira_file, :jira_val
  end
end
