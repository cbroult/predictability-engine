# frozen_string_literal: true

require 'yaml'

module PredictabilityEngine
  class Config
    CONFIG_FILE = '.predictability_engine.yml'
    JIRA_CREDENTIALS_FILE = File.expand_path('~/.config/jira/jira_credentials.yml')

    def self.jira(profile_name = nil)
      load_jira_config(profile_name)
    end

    def self.load_jira_config(profile_name = nil)
      profile_name ||= ENV['JIRA_PROFILE'] || ENV['JIRA_PROJECT']

      # Load global JIRA credentials if exists
      global_raw = File.exist?(JIRA_CREDENTIALS_FILE) ? YAML.load_file(JIRA_CREDENTIALS_FILE) : {}
      global_raw ||= {}
      # Support both flat and nested 'jira' key in global config
      global_config = global_raw.key?('jira') ? global_raw['jira'] : global_raw
      global_profiles = global_config.fetch('profiles', {})

      # Load local project JIRA config if exists
      local_raw = File.exist?(CONFIG_FILE) ? YAML.load_file(CONFIG_FILE) : {}
      local_raw ||= {}
      local_config = local_raw.fetch('jira', {})
      local_profiles = local_config.fetch('profiles', {})

      # Prioritize profile if profile_name is explicit or from env
      if profile_name
        profile = global_profiles[profile_name.to_s] || local_profiles[profile_name.to_s] || {}
        return {
          site: profile['site'],
          email: profile['email'],
          token: profile['token'],
          project: profile['project']
        } unless profile.empty?
      end

      # Default fallback logic for global settings/env vars
      {
        site: ENV['JIRA_SITE'] || local_config['site'] || global_config['site'],
        email: ENV['JIRA_EMAIL'] || local_config['email'] || global_config['email'],
        token: ENV['JIRA_API_TOKEN'] || local_config['token'] || global_config['token'],
        project: ENV['JIRA_PROJECT'] || local_config['project'] || global_config['project']
      }
    end

    private_class_method :load_jira_config
  end
end
