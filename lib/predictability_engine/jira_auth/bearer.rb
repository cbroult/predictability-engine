# frozen_string_literal: true

module PredictabilityEngine
  module JiraAuth
    class Bearer < Base
      def jira_options(base_options)
        base_options.merge(
          auth_type: :basic,
          default_headers: base_options[:default_headers]
                           .merge('Authorization' => "Bearer #{@config[:bearer_token]}")
        )
      end
    end
  end
end
