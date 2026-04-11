# frozen_string_literal: true

require 'roo'

module PredictabilityEngine
  module DataSources
    class Excel < Base
      def perform_load(path)
        return build_work_items(mock_data('MOCK_EXCEL_DATA')) if ENV['MOCK_EXCEL_DATA']

        xlsx = Roo::Spreadsheet.open(path)
        iterator = xlsx.sheet(0).each(id: 'id', start_date: 'start_date', end_date: 'end_date')
                       .reject { |row| row[:id] == 'id' }
        load_data(iterator)
      end
    end
  end
end
