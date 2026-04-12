# frozen_string_literal: true

require 'jira-ruby'
require_relative 'jira_yaml'

module PredictabilityEngine
  module DataSources
    class Jira < Base
      def perform_load(spec)
        if ENV['MOCK_JIRA'] == 'true'
          data = mock_data('JIRA_MOCK_DATA')
          # Even when mocked, we can validate the contract if requested
          if ENV['JIRA_CONTRACT_CHECK'] == 'true'
            data.each { |row| validate_issue_contract!(row) }
          end
          return build_work_items(data)
        end

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
        # Handle both JIRA::Resource::Issue and Hash (for mocks)
        is_hash = issue.is_a?(Hash)
        
        key = is_hash ? issue[:key] || issue['key'] : issue.key
        summary = is_hash ? issue[:summary] || issue['summary'] : issue.summary
        issuetype = is_hash ? issue[:issuetype] || issue['issuetype'] : issue.issuetype
        created = is_hash ? issue[:created] || issue['created'] : issue.created

        raise Error, "Issue #{key} is missing 'key'" unless key
        raise Error, "Issue #{key} is missing 'summary'" unless summary
        raise Error, "Issue #{key} is missing 'issuetype'" unless issuetype
        
        # Handle issuetype object or string
        type_name = if issuetype.respond_to?(:name)
                      issuetype.name
                    elsif issuetype.is_a?(Hash)
                      issuetype[:name] || issuetype['name']
                    else
                      issuetype
                    end
        raise Error, "Issue #{key} is missing 'issuetype.name'" unless type_name
        
        raise Error, "Issue #{key} is missing 'created'" unless created
        
        # Required for cycle time and aging
        has_changelog = is_hash ? (issue[:changelog] || issue['changelog']) : (issue.respond_to?(:changelog) && issue.changelog)
        unless has_changelog
          warn "Warning: Issue #{key} is missing 'changelog' (expand=changelog failed?)"
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
        
        # Validate configuration before building client
        raise Error, "Jira site not configured (use JIRA_SITE env var or ~/.config/jira/jira_credentials.yml)" unless config[:site]
        raise Error, "Jira email not configured (use JIRA_EMAIL env var or ~/.config/jira/jira_credentials.yml)" unless config[:email]
        raise Error, "Jira API token not configured (use JIRA_API_TOKEN env var or ~/.config/jira/jira_credentials.yml)" unless config[:token]

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
