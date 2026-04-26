# frozen_string_literal: true

module PredictabilityEngine
  module JiraAuth
    class Cookie < Base
      def jira_options(base_options)
        base_options.merge(
          auth_type: :basic,
          use_cookies: true,
          additional_cookies: [@config[:auth_cookie]]
        )
      end
    end
  end
end
