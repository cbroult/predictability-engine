# frozen_string_literal: true

require 'yaml'

module PredictabilityEngine
  module DataSources
    class JiraYaml
      PROJECT_KEY_PATTERN = /\A[A-Z][A-Z0-9]+\z/

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

      def workflow_config_path
        raw = @config['workflow_config']
        if raw && !raw.to_s.empty?
          return Pathname.new(raw).absolute? ? raw : File.expand_path(raw, @path.dirname.to_s)
        end

        name = middle_segment
        return nil if name.nil? || name.empty?

        candidate = File.expand_path("~/.config/jira/#{name}.workflow.yml")
        candidate if File.exist?(candidate)
      end

      private

      def load_config
        return {} unless @path.exist?

        YAML.load_file(@path) || {}
      rescue StandardError
        {}
      end

      def middle_segment
        if @path.basename.to_s.count('.') >= 2
          @path.basename.to_s.split('.')[1...-1].join('.')
        else
          @path.basename.to_s.sub(@path.extname, '')
        end
      end

      def convention_query
        name = middle_segment
        return nil if name.nil? || name.empty?
        return "(project = \"#{name}\" OR filter = \"#{name}\")" if name.match?(PROJECT_KEY_PATTERN)

        "filter = \"#{name}\""
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
