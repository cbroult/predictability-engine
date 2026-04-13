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
          data.each { |row| validate_issue_contract!(row) } if ENV['JIRA_CONTRACT_CHECK'] == 'true'
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
        key = get_field(issue, :key, is_hash)
        validate_basic_fields(issue, key, is_hash)
        validate_issuetype(issue, key, is_hash)
        validate_created(issue, key, is_hash)
        validate_changelog(issue, key, is_hash)
      end

      def validate_basic_fields(issue, key, is_hash)
        summary = get_field(issue, :summary, is_hash)
        raise Error, "Issue #{key} is missing 'key'" unless key
        raise Error, "Issue #{key} is missing 'summary'" unless summary
      end

      def validate_issuetype(issue, key, is_hash)
        issuetype = get_field(issue, :issuetype, is_hash)
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
      end

      def validate_created(issue, key, is_hash)
        created = get_field(issue, :created, is_hash)
        raise Error, "Issue #{key} is missing 'created'" unless created
      end

      def validate_changelog(issue, key, is_hash)
        # Required for cycle time and aging
        has_changelog = if is_hash
                          issue[:changelog] || issue['changelog']
                        else
                          issue.respond_to?(:changelog) && issue.changelog
                        end
        return if has_changelog

        warn "Warning: Issue #{key} is missing 'changelog' (expand=changelog failed?)"
      end

      def get_field(issue, name, is_hash)
        is_hash ? issue[name] || issue[name.to_s] : issue.send(name)
      end

      def resolve_source(spec)
        profile_name = ENV.fetch('JIRA_PROFILE', nil)
        case spec
        when /\.ya?ml$/
          yaml = JiraYaml.new(spec)
          [yaml.profile, yaml.query]
        when 'jira'
          [profile_name, query_from_config(profile_name)]
        when /^[A-Z][A-Z0-9]+$/
          [profile_name, "project = \"#{spec}\""]
        else
          [nil, spec]
        end
      end

      def query_from_config(profile_name)
        config = Config.jira(profile_name)
        project = config[:project]
        query = ENV.fetch('JIRA_PROJECT_QUERY', nil) || (project ? "project = \"#{project}\"" : nil)
        raise Error, 'No JIRA project specified (use JIRA_PROJECT env var or provide a query)' unless query

        query
      end

      def build_client(profile = nil)
        Config.jira_client(profile)
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

        transitions = status_transitions(issue.changelog.fetch('histories', []))
        in_progress_keywords = ['In Progress', 'Doing', 'Active', 'Development', 'Progress']

        match = transitions.sort_by { |t| t[:date] }.find do |t|
          in_progress_keywords.any? { |kw| t[:to].downcase.include?(kw.downcase) }
        end

        match ? match[:date] : nil
      end

      def status_transitions(histories)
        histories.flat_map do |history|
          created_at = history['created']
          history['items'].select { |item| item['field'] == 'status' }.map do |item|
            { date: created_at, to: item['toString'] }
          end
        end
      end
    end
  end
end
