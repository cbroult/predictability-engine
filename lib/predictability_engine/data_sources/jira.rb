# frozen_string_literal: true

require 'jira-ruby'

module PredictabilityEngine
  module DataSources
    class Jira < Base
      def perform_load(spec)
        return build_work_items(mock_data('JIRA_MOCK_DATA')) if ENV['MOCK_JIRA'] == 'true'

        client = build_client
        issues = fetch_issues(client, spec)
        data = issues.map { |issue| map_issue(issue) }
        build_work_items(data)
      end

      private

      def build_client
        config = Config.jira
        options = {
          username: config[:email],
          password: config[:token],
          site: config[:site],
          context_path: '',
          auth_type: :basic
        }
        ::JIRA::Client.new(options)
      end

      def fetch_issues(client, spec)
        jql = spec.start_with?('jira:') ? "filter = #{spec.sub('jira:', '')}" : spec.sub('jql:', '')
        client.Issue.jql(jql)
      end

      def map_issue(issue)
        map_row({
                  id: issue.key,
                  created: issue.created,
                  resolutiondate: issue.resolutiondate
                })
      end
    end
  end
end
