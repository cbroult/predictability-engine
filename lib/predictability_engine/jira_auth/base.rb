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

      protected

      def bearer_merge(base_options, token)
        base_options.merge(
          auth_type: :basic,
          default_headers: base_options[:default_headers].merge('Authorization' => "Bearer #{token}")
        )
      end
    end
  end
end
