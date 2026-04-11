# frozen_string_literal: true

require 'csv'

module PredictabilityEngine
  module DataSources
    class Csv < Base
      def perform_load(path)
        CSV.open(path, headers: true, header_converters: :symbol).then { |csv| load_data(csv) }
      end
    end
  end
end
