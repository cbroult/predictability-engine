# frozen_string_literal: true

require 'csv'

module PredictabilityEngine
  module DataSources
    class Csv < Base
      JIRA_HEADER_MAP = {
        issue_key: :id,
        issue_type: :type
      }.freeze

      def perform_load(path)
        CSV.open(path, headers: true, header_converters: :symbol)
           .then { |csv| load_data(csv.map { |row| apply_jira_header_map(row.to_h) }) }
      end

      private

      def apply_jira_header_map(row_hash)
        row_hash.transform_keys { |k| JIRA_HEADER_MAP.fetch(k, k) }
      end
    end
  end
end
