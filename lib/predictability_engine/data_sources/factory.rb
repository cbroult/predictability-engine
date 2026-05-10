# frozen_string_literal: true

module PredictabilityEngine
  module DataSources
    class Factory
      def self.for(spec, **opts)
        source = case spec
                 when /^jira:/, /^jql:/, /\.yml$/, /\.yaml$/, 'jira', /^[A-Z][A-Z0-9]+$/
                   Jira.new
                 when /\.xlsx$/
                   Excel.new
                 else
                   Csv.new
                 end
        source.configure(opts)
        source
      end
    end
  end
end
