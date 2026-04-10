# frozen_string_literal: true

module PredictabilityEngine
  class DataManager
    attr_reader :work_items

    def initialize
      @work_items = []
    end

    def load_csv(file_path)
      CSV.foreach(file_path, headers: true) do |row|
        @work_items << Models::WorkItem.new(
          id: row['id'] || row['Issue key'],
          title: row['title'] || row['Summary'],
          start_date: row['start_date'] || row['Created'], # Fallback, should ideally be transition date
          end_date: row['end_date'] || row['Resolved']
        )
      end
    end

    def completed_items
      @work_items.select(&:completed?)
    end

    def active_items
      @work_items.reject(&:completed?)
    end
  end
end
