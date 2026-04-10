# frozen_string_literal: true

module PredictabilityEngine
  module Calculators
    class Throughput
      def self.daily(work_items, start_date: nil, end_date: nil)
        completed = work_items.select(&:completed?)
        return {} if completed.empty?

        start_date ||= completed.map(&:end_date).min
        end_date ||= completed.map(&:end_date).max

        counts = initial_daily_counts(start_date, end_date)
        populate_daily_counts(counts, completed, start_date, end_date)
      end

      def self.initial_daily_counts(start_date, end_date)
        (start_date..end_date).to_h { |d| [d, 0] }
      end

      def self.populate_daily_counts(counts, completed, start_date, end_date)
        completed.each do |item|
          next if item.end_date < start_date || item.end_date > end_date

          counts[item.end_date] += 1
        end
        counts
      end

      def self.average(work_items, start_date: nil, end_date: nil)
        counts = daily(work_items, start_date: start_date, end_date: end_date).values
        return 0 if counts.empty?

        counts.sum.to_f / counts.size
      end
    end
  end
end
