# frozen_string_literal: true

module PredictabilityEngine
  module JiraAuth
    class Bearer < Base
      def jira_options(base_options)
        bearer_merge(base_options, @config[:bearer_token])
      end
    end
  end
end
