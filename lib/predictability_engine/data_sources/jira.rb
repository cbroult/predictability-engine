# frozen_string_literal: true

require 'jira-ruby'
require_relative 'jira_yaml'

module PredictabilityEngine
  module DataSources
    class Jira < Base
      IN_PROGRESS_KEYWORDS = ['In Progress', 'Doing', 'Active', 'Development', 'Progress'].freeze
      FIELDS = %w[summary issuetype created priority resolutiondate status].freeze

      def perform_load(spec)
        @priority_aliases = yaml_priority_aliases(spec)

        if ENV['MOCK_JIRA'] == 'true'
          data = mock_data('JIRA_MOCK_DATA')
          # Even when mocked, we can validate the contract if requested
          data.each { |row| validate_issue_contract!(row) } if ENV['JIRA_CONTRACT_CHECK'] == 'true'
          return build_work_items(data)
        end

        profile, query, @workflow = resolve_source(spec)
        @jira_site = Config.jira(profile)[:site]
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

        PredictabilityEngine.logger.warn { "Issue #{key} is missing 'changelog' (expand=changelog failed?)" }
      end

      def get_field(issue, name, is_hash)
        is_hash ? issue[name] || issue[name.to_s] : issue.send(name)
      end

      def yaml_priority_aliases(spec)
        return {} unless spec.is_a?(String) && spec.match?(/\.ya?ml$/)

        JiraYaml.new(spec).priority_aliases
      end

      def resolve_source(spec)
        profile_name = ENV.fetch('JIRA_PROFILE', nil)
        case spec
        when /\.ya?ml$/
          yaml = JiraYaml.new(spec)
          [yaml.profile, yaml.query, load_workflow(yaml.workflow_config_path, yaml.profile)]
        when 'jira'
          [profile_name, query_from_config(profile_name), load_workflow(nil, profile_name)]
        when /^[A-Z][A-Z0-9]+$/
          [profile_name, "project = \"#{spec}\"", load_workflow(nil, profile_name)]
        else
          [nil, spec, nil]
        end
      end

      def load_workflow(explicit_path, profile_name)
        return JiraWorkflow.load(explicit_path) if explicit_path

        profile_name && JiraWorkflow.load(JiraWorkflow.default_path(profile_name))
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
        logger.debug { "JIRA JQL: #{jql}" }
        client.Issue.jql(jql, expand: 'changelog', fields: FIELDS)
      rescue StandardError => e
        logger.debug { "JIRA fetch failed: #{e.class} — #{e.message}" }
        raise Error, "Failed to fetch issues from Jira: #{e.message}"
      end

      def map_issue(issue)
        map_row({
                  id: issue.key,
                  url: "#{@jira_site.to_s.chomp('/')}/browse/#{issue.key}",
                  summary: issue.summary,
                  issuetype: issue.issuetype.name,
                  priority: jira_priority_name(issue),
                  created: issue.created,
                  start_date: first_in_progress_date(issue),
                  resolutiondate: last_departure_date(issue)
                })
      end

      def jira_priority_name(issue)
        return nil unless issue.respond_to?(:priority) && issue.priority

        issue.priority.respond_to?(:name) ? issue.priority.name : issue.priority.to_s
      end

      def first_in_progress_date(issue)
        names = @workflow&.arrival_names
        return first_transition_matching(issue) { |t| names.any? { |n| t[:to].casecmp?(n) } } if names&.any?

        warn_missing_workflow_once
        first_transition_matching(issue) do |t|
          IN_PROGRESS_KEYWORDS.any? { |kw| t[:to].downcase.include?(kw.downcase) }
        end
      end

      def last_departure_date(issue)
        names = @workflow&.departure_names
        return issue.resolutiondate unless names&.any?

        first_transition_matching(issue) { |t| names.any? { |n| t[:to].casecmp?(n) } } || issue.resolutiondate
      end

      def first_transition_matching(issue, &)
        return nil unless issue.respond_to?(:changelog) && issue.changelog

        transitions = status_transitions(issue.changelog.fetch('histories', [])).sort_by { |t| t[:date] }
        match = transitions.find(&)
        match ? match[:date] : nil
      end

      def warn_missing_workflow_once
        return if @workflow_warning_emitted

        @workflow_warning_emitted = true
        PredictabilityEngine.logger.warn do
          'No Jira workflow mapping found; falling back to in-progress keyword heuristic. ' \
            'Run `./bin/predictability-engine jira_workflow <profile>` to generate an editable mapping.'
        end
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
