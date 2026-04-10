# frozen_string_literal: true

module PredictabilityEngine
  module Calculators
    class Cfd
      def self.calculate(work_items, start_date: nil, end_date: nil)
        return [] if work_items.empty?

        start_date ||= work_items.map(&:start_date).compact.min
        end_date ||= Date.today

        (start_date..end_date).map do |day|
          calculate_for_day(work_items, day)
        end
      end

      def self.calculate_for_day(work_items, day)
        arrived = work_items.select { |item| item.start_date && item.start_date <= day }.count
        departed = work_items.select { |item| item.end_date && item.end_date <= day }.count
        wip = [arrived - departed, 0].max

        {
          date: day,
          arrived: arrived,
          departed: departed,
          wip: wip
        }
      end
    end
  end
end
