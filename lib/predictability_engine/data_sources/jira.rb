# frozen_string_literal: true

require 'jira-ruby'
require_relative 'jira_yaml'

module PredictabilityEngine
  module DataSources
    class Jira < Base
      def perform_load(spec)
        return build_work_items(mock_data('JIRA_MOCK_DATA')) if ENV['MOCK_JIRA'] == 'true'

        profile, query = resolve_source(spec)
        client = build_client(profile)
        issues = fetch_issues(client, query)
        
        # Contract Validation
        issues.each { |issue| validate_issue_contract!(issue) } if ENV['JIRA_CONTRACT_CHECK'] == 'true'
        
        data = issues.map { |issue| map_issue(issue) }
        build_work_items(data)
      end

      private

      def validate_issue_contract!(issue)
        # Required fields according to map_issue
        raise Error, "Issue #{issue.key} is missing 'key'" unless issue.key
        raise Error, "Issue #{issue.key} is missing 'summary'" unless issue.summary
        raise Error, "Issue #{issue.key} is missing 'issuetype'" unless issue.issuetype
        raise Error, "Issue #{issue.key} is missing 'issuetype.name'" unless issue.issuetype.name
        raise Error, "Issue #{issue.key} is missing 'created'" unless issue.created
        
        # Required for cycle time and aging
        unless issue.respond_to?(:changelog) && issue.changelog
          warn "Warning: Issue #{issue.key} is missing 'changelog' (expand=changelog failed?)"
        end
      end

      def resolve_source(spec)
        profile_name = ENV['JIRA_PROFILE']
        if spec.end_with?('.yml') || spec.end_with?('.yaml')
          yaml = JiraYaml.new(spec)
          [yaml.profile, yaml.query]
        elsif spec == 'jira'
          config = Config.jira(profile_name)
          project = config[:project]
          query = ENV['JIRA_PROJECT_QUERY'] || (project ? "project = \"#{project}\"" : nil)
          raise Error, "No JIRA project specified (use JIRA_PROJECT env var or provide a query)" unless query
          [profile_name, query]
        elsif spec.match?(/^[A-Z][A-Z0-9]+$/)
          [profile_name, "project = \"#{spec}\""]
        else
          [nil, spec]
        end
      end

      def build_client(profile = nil)
        config = Config.jira(profile)
        options = {
          username: config[:email],
          password: config[:token],
          site: config[:site],
          context_path: '',
          auth_type: :basic
        }
        ::JIRA::Client.new(options)
      end

      def fetch_issues(client, query)
        jql = query.start_with?('jira:') ? "filter = #{query.sub('jira:', '')}" : query.sub('jql:', '')
        client.Issue.jql(jql, expand: 'changelog')
      end

      def map_issue(issue)
        map_row({
                  id: issue.key,
                  summary: issue.summary,
                  issuetype: issue.issuetype.name,
                  created: issue.created,
                  start_date: first_in_progress_date(issue),
                  resolutiondate: issue.resolutiondate
                })
      end

      def first_in_progress_date(issue)
        return nil unless issue.respond_to?(:changelog) && issue.changelog

        histories = issue.changelog.fetch('histories', [])
        transitions = histories.flat_map do |history|
          history['items'].select { |item| item['field'] == 'status' }.map do |item|
            { date: history['created'], to: item['toString'] }
          end
        end

        # Find the first transition to any status that is NOT in the "To Do" category
        # Since we don't have category info easily, we'll use common names as a fallback
        # or better: the first transition that moves AWAY from the initial status if it's a known "To Do" status.
        # For simplicity, let's use a configurable or common list of "In Progress" statuses.
        in_progress_keywords = ['In Progress', 'Doing', 'Active', 'Development', 'Progress']
        
        match = transitions.sort_by { |t| t[:date] }.find do |t|
          in_progress_keywords.any? { |kw| t[:to].downcase.include?(kw.downcase) }
        end

        match ? match[:date] : nil
      end
    end
  end
end
