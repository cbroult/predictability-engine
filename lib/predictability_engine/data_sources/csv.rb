# frozen_string_literal: true

require 'csv'
require 'yaml'

module PredictabilityEngine
  module DataSources
    class Csv < Base
      JIRA_HEADER_MAP = {
        issue_key: :id,
        issue_type: :type
      }.freeze

      def perform_load(path)
        resolved = resolve_path(path)
        config = load_csv_config(resolved)
        @url_prefix ||= config['url_prefix']
        @done_statuses = load_done_statuses(config)
        @source_url = "file://#{File.expand_path(resolved)}"
        CSV.open(resolved, headers: true, header_converters: :symbol, encoding: 'bom|UTF-8', row_sep: :auto)
           .then { |csv| load_data(csv.map { |row| apply_jira_header_map(row.to_h) }) }
      end

      private

      def apply_jira_header_map(row_hash)
        row_hash.transform_keys { |k| JIRA_HEADER_MAP.fetch(k, k) }
      end

      def map_row(row)
        super.tap do |mapped|
          mapped[:url] ||= @source_url unless @url_prefix
          next if mapped[:end_date]
          next unless @done_statuses.include?(row[:status].to_s.downcase)

          mapped[:end_date] = parse_date(row[:updated])
        end
      end

      def load_done_statuses(config)
        if (wf_path = config['workflow_config_path'])
          JiraWorkflow.load(File.expand_path(wf_path))&.departure_names.to_a.map(&:downcase)
        elsif config.key?('statuses')
          JiraWorkflow.new(statuses: Array(config['statuses'])).departure_names.map(&:downcase)
        else
          Array(config['done_statuses']).map(&:downcase)
        end
      end

      def load_csv_config(csv_path)
        sidecar = csv_path.sub(/\.csv$/i, '.yml')
        return YAML.load_file(sidecar) || {} if File.exist?(sidecar)
        return project_jira_csv_config if File.exist?(Config::CONFIG_FILE)

        {}
      end

      def project_jira_csv_config
        (YAML.load_file(Config::CONFIG_FILE) || {}).fetch('jira_csv', {})
      end
    end
  end
end
