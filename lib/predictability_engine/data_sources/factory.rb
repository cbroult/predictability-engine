# frozen_string_literal: true

module PredictabilityEngine
  module DataSources
    class Factory
      def self.for(spec)
        case spec
        when /^jira:/, /^jql:/
          Jira.new
        when /\.xlsx$/
          Excel.new
        else
          Csv.new
        end
      end
    end
  end
end
