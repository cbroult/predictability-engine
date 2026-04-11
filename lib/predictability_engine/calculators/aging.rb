# frozen_string_literal: true

module PredictabilityEngine
  module Calculators
    class Aging
      def self.current_wip(work_items, date = Date.today)
        work_items.select { |item| item.in_progress?(date) }
      end

      def self.item_age_data(work_items, date = Date.today)
        data = current_wip(work_items, date).map do |item|
          {
            id: item.id,
            title: item.title,
            age: item.age(date),
            start_date: item.start_date
          }
        end
        data.sort_by { |d| d[:age] }.reverse
      end
    end
  end
end
