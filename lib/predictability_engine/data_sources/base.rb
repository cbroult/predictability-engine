# frozen_string_literal: true

module PredictabilityEngine
  module DataSources
    class Base
      def load(source_spec)
        perform_load(source_spec)
      rescue StandardError => e
        raise Error, "Failed to load from #{source_name}: #{e.message}"
      end

      protected

      def source_name
        self.class.name.split('::').last
      end

      def perform_load(_source_spec)
        raise NotImplementedError, "#{self.class} must implement perform_load"
      end

      def build_work_items(data)
        data.map do |row|
          item_data = map_row(row)
          item_id = item_data.delete(:id)
          Models::WorkItem.new(item_id: item_id, **item_data)
        end
      end

      def parse_date(val)
        return val if val.is_a?(Date) || val.is_a?(Time)
        return nil if val.nil? || val.to_s.strip.empty?

        Date.parse(val.to_s)
      rescue ArgumentError
        nil
      end

      def load_data(iterator)
        data = iterator.map do |row|
          map_row(row)
        end
        build_work_items(data)
      end

      def map_row(row)
        {
          id: row[:id] || row[:key] || row[:item_id],
          title: row[:title] || row[:summary],
          type: row[:type] || row[:issuetype],
          start_date: parse_date(row[:start_date] || row[:created]),
          end_date: parse_date(row[:end_date] || row[:resolutiondate] || row[:resolved])
        }
      end

      def mock_data(env_key)
        json = ENV.fetch(env_key, '[]')
        JSON.parse(json, symbolize_names: true)
      end
    end
  end
end
