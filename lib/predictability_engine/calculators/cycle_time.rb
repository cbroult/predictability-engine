# frozen_string_literal: true

module PredictabilityEngine
  module Calculators
    class CycleTime
      def self.distribution(work_items)
        completed = work_items.select(&:completed?)
        return [] if completed.empty?

        completed.map(&:cycle_time).sort
      end

      def self.percentile(work_items, percentile_value)
        dist = distribution(work_items)
        return nil if dist.empty?

        index = (dist.size * percentile_value / 100.0).ceil - 1
        dist[index]
      end

      def self.completed_sorted(work_items)
        PredictabilityEngine.completed_items(work_items).sort_by(&:end_date)
      end
    end
  end
end
