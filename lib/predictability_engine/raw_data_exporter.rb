# frozen_string_literal: true

require 'csv'

module PredictabilityEngine
  module RawDataExporter
    DONE_THRESHOLDS = [1, 7, 14, 21, 28].freeze
    DONE_THRESHOLD_LABELS = (DONE_THRESHOLDS.map { |d| d == 1 ? '≤ 1 day' : "≤ #{d} days" } +
                             ["> #{DONE_THRESHOLDS.last} days"]).freeze

    HEADERS = [
      'ID', 'Title', 'Type', 'Priority',
      'Start Date', 'End Date', 'Status',
      'YYYY-Week', 'YYYY-MM', 'YYYY',
      'Cycle Time (days)', 'Current Age (days)', 'URL',
      'Done ≤ 1 day', 'Done ≤ 7 days', 'Done ≤ 14 days',
      'Done ≤ 21 days', 'Done ≤ 28 days'
    ].freeze

    def self.item_row(item)
      today = PredictabilityEngine.today
      ct    = item.cycle_time
      age   = item.completed? ? nil : item.age(today)
      flags = DONE_THRESHOLDS.map { |d| ct ? ct <= d : nil }
      date  = item.end_date
      [item.id, item.title, item.type, item.priority,
       item.start_date, item.end_date,
       (item.completed? ? 'Done' : 'In Progress'),
       PredictabilityEngine.format_year_week(date),
       PredictabilityEngine.format_year_month(date),
       date&.to_date&.year,
       ct, age, item.url.to_s, *flags]
    end

    def self.threshold_index(cycle_time)
      DONE_THRESHOLDS.index { |d| cycle_time <= d } || DONE_THRESHOLDS.size
    end

    def self.generate_csv(items)
      CSV.generate do |csv|
        csv << HEADERS
        items.each { |item| csv << item_row(item) }
      end
    end
  end
end
