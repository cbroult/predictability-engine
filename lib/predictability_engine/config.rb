# frozen_string_literal: true

require 'yaml'

module PredictabilityEngine
  class Config
    CONFIG_FILE = '.predictability_engine.yml'

    def self.jira
      @jira ||= load_jira_config
    end

    def self.load_jira_config
      file_config = File.exist?(CONFIG_FILE) ? YAML.load_file(CONFIG_FILE).fetch('jira', {}) : {}
      {
        site: ENV.fetch('JIRA_SITE', file_config['site']),
        email: ENV.fetch('JIRA_EMAIL', file_config['email']),
        token: ENV.fetch('JIRA_API_TOKEN', file_config['token'])
      }
    end

    private_class_method :load_jira_config
  end
end
