# frozen_string_literal: true

require 'yaml'

module PredictabilityEngine
  class Config
    CONFIG_FILE = '.predictability_engine.yml'

    def self.jira(profile_name = nil)
      load_jira_config(profile_name)
    end

    def self.load_jira_config(profile_name = nil)
      all_config = File.exist?(CONFIG_FILE) ? YAML.load_file(CONFIG_FILE) : {}
      jira_config = all_config.fetch('jira', {})
      profiles = jira_config.fetch('profiles', {})

      profile = profile_name ? profiles.fetch(profile_name.to_s, {}) : {}

      {
        site: profile['site'] || jira_config['site'] || ENV['JIRA_SITE'],
        email: profile['email'] || jira_config['email'] || ENV['JIRA_EMAIL'],
        token: profile['token'] || jira_config['token'] || ENV['JIRA_API_TOKEN']
      }
    end

    private_class_method :load_jira_config
  end
end
