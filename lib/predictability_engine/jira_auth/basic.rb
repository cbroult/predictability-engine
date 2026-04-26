# frozen_string_literal: true

module PredictabilityEngine
  module JiraAuth
    class Basic < Base
      def jira_options(base_options)
        base_options.merge(
          username: @config[:email],
          password: @config[:token],
          auth_type: :basic
        )
      end
    end
  end
end
