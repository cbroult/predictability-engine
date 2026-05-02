# frozen_string_literal: true

require 'csv'

module PredictabilityEngine
  module RawDataExporter
    DONE_THRESHOLDS = [1, 7, 14, 21, 28].freeze

    HEADERS = [
      'ID', 'Title', 'Type', 'Priority',
      'Start Date', 'End Date', 'Status',
      'Cycle Time (days)', 'Current Age (days)',
      'Done ≤ 1 day', 'Done ≤ 7 days', 'Done ≤ 14 days',
      'Done ≤ 21 days', 'Done ≤ 28 days'
    ].freeze

    def self.item_row(item)
      today = PredictabilityEngine.today
      ct    = item.cycle_time
      age   = item.completed? ? nil : item.age(today)
      flags = DONE_THRESHOLDS.map { |d| ct ? ct <= d : nil }
      [item.id, item.title, item.type, item.priority,
       item.start_date, item.end_date,
       (item.completed? ? 'Done' : 'In Progress'),
       ct, age, *flags]
    end

    def self.generate_csv(items)
      CSV.generate do |csv|
        csv << HEADERS
        items.each { |item| csv << item_row(item) }
      end
    end
  end
end
