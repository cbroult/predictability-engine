# frozen_string_literal: true

require 'yaml'
require 'pathname'

module PredictabilityEngine
  module DataSources
    class JiraYaml
      attr_reader :path, :config

      def initialize(path)
        @path = Pathname.new(path)
        @config = load_config
      end

      def profile
        return @config['jira_profile'] if @config['jira_profile']
        return nil unless @path.basename.to_s.count('.') >= 2
        @path.basename.to_s.split('.').first
      end

      def query
        @config['query'] || project_query || filter_query || convention_query
      end

      private

      def load_config
        return {} unless @path.exist?
        YAML.load_file(@path) || {}
      rescue StandardError
        {}
      end

      def convention_query
        name = if @path.basename.to_s.count('.') >= 2
                 @path.basename.to_s.split('.')[1...-1].join('.')
               else
                 @path.basename.to_s.sub(@path.extname, '')
               end
        name.empty? ? nil : "filter = \"#{name}\""
      end

      def project_query
        return nil unless @config['project']
        "project = \"#{@config['project']}\""
      end

      def filter_query
        return "filter = \"#{@config['filter_id']}\"" if @config['filter_id']
        return "filter = \"#{@config['filter_name']}\"" if @config['filter_name']
        nil
      end
    end
  end
end
