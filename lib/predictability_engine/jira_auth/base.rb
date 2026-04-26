# frozen_string_literal: true

module PredictabilityEngine
  module JiraAuth
    class Base
      def initialize(config)
        @config = config
      end

      def jira_options(_base_options)
        raise NotImplementedError, "#{self.class} must implement jira_options"
      end

      def post_init(_client); end
    end
  end
end
