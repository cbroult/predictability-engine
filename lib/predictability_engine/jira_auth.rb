# frozen_string_literal: true

require_relative 'jira_auth/base'
require_relative 'jira_auth/basic'
require_relative 'jira_auth/bearer'
require_relative 'jira_auth/cookie'
require_relative 'jira_auth/mfa_api'
require_relative 'jira_auth/mfa_browser'

module PredictabilityEngine
  module JiraAuth
    MODES = %w[basic bearer cookie mfa_api mfa_browser].freeze

    def self.build(config)
      mode = config[:auth_mode].to_s
      mode = 'basic' if mode.empty?
      raise Error, "Unknown Jira auth_mode '#{mode}'" unless MODES.include?(mode)

      const_get(mode.split('_').map(&:capitalize).join).new(config)
    end
  end
end
