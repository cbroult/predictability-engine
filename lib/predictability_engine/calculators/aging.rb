# frozen_string_literal: true

module PredictabilityEngine
  module Calculators
    class Aging
      def self.current_wip(work_items, date = PredictabilityEngine.today)
        work_items.select { |item| item.in_progress?(date) }
      end

      def self.summary_metrics(work_items, date = PredictabilityEngine.today)
        wip = current_wip(work_items, date)
        return nil if wip.empty?

        ages = wip.map { |item| item.age(date) }
        {
          count: wip.size,
          avg_age: (ages.sum.to_f / ages.size).round(1),
          max_age: ages.max
        }
      end

      def self.item_age_data(work_items, date = PredictabilityEngine.today)
        data = current_wip(work_items, date).map do |item|
          {
            id: item.id,
            title: item.title,
            age: item.age(date),
            start_date: item.start_date,
            url: item.url
          }
        end
        data.sort_by { |d| d[:age] }.reverse
      end
    end
  end
end
