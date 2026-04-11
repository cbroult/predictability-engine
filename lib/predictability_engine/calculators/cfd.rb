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

        { date: day, arrived: arrived, departed: departed, wip: wip }
      end

      def self.to_coordinates(cfd_data, start_date)
        { dates: cfd_data.map { |d| (d[:date] - start_date).to_i },
          arrived: cfd_data.map { |d| d[:arrived] },
          departed: cfd_data.map { |d| d[:departed] } }
      end

      def self.forecast_summary(work_items, trials: 10_000, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        historical_tp = Throughput.daily(work_items).values
        wip_count = work_items.select { |wi| wi.start_date && !wi.end_date }.count

        return nil if wip_count.zero? || historical_tp.empty?

        results = Simulators::MonteCarlo.when_will_it_be_done(wip_count, historical_tp, trials: trials)
        build_forecast_result(work_items, results, wip_count, percentiles)
      end

      def self.build_forecast_result(work_items, results, wip_count, percentiles)
        res = {
          today: Date.today,
          wip: wip_count,
          total_items: work_items.select(&:start_date).count,
          departed_so_far: work_items.select(&:completed?).count
        }
        percentiles.each do |p|
          res[:"p#{p}"] = Simulators::MonteCarlo.percentile(results, p)
        end
        res
      end

      def self.forecast_points(work_items, trials: 10_000, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        summary = forecast_summary(work_items, trials: trials, percentiles: percentiles)
        return nil unless summary

        points = { summary: summary, max_days: max_forecast_days(summary, percentiles) }
        percentiles.each do |p|
          points[:"p#{p}"] = build_points(summary, :"p#{p}")
        end
        points
      end

      def self.max_forecast_days(summary, percentiles)
        percentiles.map { |p| summary[:"p#{p}"] }.compact.max || 0
      end

      def self.with_forecast(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        forecast = forecast_points(work_items, percentiles: percentiles)
        return yield(nil) unless forecast

        yield(forecast)
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
