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

      def self.forecast_summary(work_items, trials: 10_000)
        historical_tp = Throughput.daily(work_items).values
        wip_count = work_items.select { |wi| wi.start_date && !wi.end_date }.count

        return nil if wip_count.zero? || historical_tp.empty?

        results = Simulators::MonteCarlo.when_will_it_be_done(wip_count, historical_tp, trials: trials)
        build_forecast_result(work_items, results, wip_count)
      end

      def self.build_forecast_result(work_items, results, wip_count)
        {
          today: Date.today,
          wip: wip_count,
          total_items: work_items.select(&:start_date).count,
          departed_so_far: work_items.select(&:completed?).count,
          p50: Simulators::MonteCarlo.percentile(results, 50),
          p85: Simulators::MonteCarlo.percentile(results, 85),
          p95: Simulators::MonteCarlo.percentile(results, 95)
        }
      end

      def self.forecast_points(work_items, trials: 10_000)
        summary = forecast_summary(work_items, trials: trials)
        return nil unless summary

        {
          summary: summary,
          p50: build_points(summary, :p50),
          p85: build_points(summary, :p85),
          p95: build_points(summary, :p95)
        }
      end

      def self.build_points(summary, p_key)
        [
          { date: summary[:today], count: summary[:departed_so_far] },
          { date: summary[:today] + summary[p_key], count: summary[:total_items] }
        ]
      end

      private_class_method :build_forecast_result, :build_points
    end
  end
end
