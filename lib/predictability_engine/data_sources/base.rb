# frozen_string_literal: true

require 'yaml'

module PredictabilityEngine
  module DataSources
    class Base
      def configure(opts)
        @url_prefix = opts[:url_prefix]
        self
      end

      def load(source_spec)
        apply_project_config_defaults
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
        raw_id = row[:id] || row[:key] || row[:item_id]
        {
          id: raw_id,
          title: row[:title] || row[:summary],
          type: row[:type] || row[:issuetype],
          priority: normalize_priority(row[:priority]),
          start_date: parse_date(row[:start_date] || row[:created]),
          end_date: parse_date(row[:end_date] || row[:resolutiondate] || row[:resolved]),
          url: item_url(row[:url], raw_id)
        }
      end

      def item_url(url, item_id)
        url.presence || (@url_prefix && "#{@url_prefix}#{item_id}")
      end

      def normalize_priority(name)
        return nil if name.nil?

        (@priority_aliases || {})[name.to_s] || name
      end

      def resolve_path(path)
        return path if Pathname.new(path).absolute? || File.exist?(path)

        gem_root = File.expand_path('../../..', __dir__)
        gem_relative = File.join(gem_root, path)
        File.exist?(gem_relative) ? gem_relative : path
      end

      def mock_data(env_key)
        json = ENV.fetch(env_key, '[]')
        JSON.parse(json, symbolize_names: true)
      end

      private

      def apply_project_config_defaults
        return if @url_prefix
        return unless File.exist?(Config::CONFIG_FILE)

        config = YAML.load_file(Config::CONFIG_FILE) || {}
        @url_prefix = config['url_prefix']
      end
    end
  end
end
