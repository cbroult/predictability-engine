# frozen_string_literal: true

require 'date'

module PredictabilityEngine
  module Calculators
    module CfdForecaster
      def self.forecast_summary(work_items, trials: 10_000, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        backlog = work_items.reject(&:completed?).size
        historical = Throughput.daily(work_items).values
        return nil if historical.empty?
        return nil if backlog.zero? && work_items.none? { |i| i.end_date && i.end_date > Date.today }

        results = simulate_backlog(backlog, historical, trials)
        days_to_future = days_to_last_scheduled_item(work_items)

        build_summary(work_items, results, days_to_future, percentiles)
      end

      def self.forecast_series(work_items, trials: 10_000, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        cfd_data = ensure_data_up_to_today(Cfd.calculate(work_items), work_items)
        return nil if cfd_data.empty?

        summary = forecast_summary(work_items, trials: trials, percentiles: percentiles)
        return nil unless summary

        today_index = cfd_data.index { |d| d[:date] == Date.today } || (cfd_data.size - 1)
        history = cfd_data[0..today_index].last(15)
        future_data = cfd_data[(today_index + 1)..] || []
        max_days = [percentiles.map { |p| summary[:"p#{p}"] }.max || 0, future_data.size].max

        { dates: build_dates(history, max_days), arrivals: build_arrivals(history, max_days, future_data),
          departed: history.map { |d| d[:departed] }, summary: summary, max_days: max_days,
          forecasts: build_forecast_map(history, summary, max_days, percentiles, future_data) }
      end

      def self.simulate_backlog(backlog, historical, trials)
        return [0] * trials if backlog.zero?

        Simulators::MonteCarlo.when_will_it_be_done(backlog, historical, trials: trials)
      end

      def self.days_to_last_scheduled_item(work_items)
        future_dates = work_items.select { |i| i.end_date && i.end_date > Date.today }.map(&:end_date)
        future_dates.map { |d| (d - Date.today).to_i }.max || 0
      end

      def self.build_summary(work_items, results, days_to_future, percentiles)
        res = { wip: work_items.reject(&:completed?).size, today: Date.today,
                total_items: work_items.size, departed_so_far: work_items.count(&:completed?) }
        percentiles.each do |p|
          sim_days = Simulators::MonteCarlo.percentile(results, p)
          res[:"p#{p}"] = [sim_days, days_to_future].max
        end
        res
      end

      def self.ensure_data_up_to_today(cfd_data, work_items)
        return Cfd.calculate(work_items, end_date: Date.today) if cfd_data.empty? || cfd_data.last[:date] < Date.today

        cfd_data
      end

      def self.build_dates(history, max_days)
        dates = history.map { |d| d[:date] }
        (1..max_days).each { |i| dates << (history.last[:date] + i) }
        dates
      end

      def self.build_arrivals(history, max_days, future_data)
        arrivals = history.map { |d| d[:arrived] }
        (1..max_days).each do |i|
          arrivals << (future_data[i - 1] ? future_data[i - 1][:arrived] : history.last[:arrived])
        end
        arrivals
      end

      def self.build_forecast_map(history, summary, max_days, percentiles, future_data)
        percentiles.each_with_object({}) do |p, h|
          days = summary[:"p#{p}"]
          res = history.map { |d| d[:departed] }
          (1..max_days).each do |i|
            fd = future_data[i - 1] ? future_data[i - 1][:departed] : summary[:departed_so_far]
            forecasted = i <= days ? (i * (summary[:wip].to_f / days)).round : summary[:wip]
            res << (fd + forecasted)
          end
          h[p] = res
        end
      end

      private_class_method :simulate_backlog, :days_to_last_scheduled_item, :build_summary,
                           :ensure_data_up_to_today, :build_dates, :build_arrivals, :build_forecast_map
    end
  end
end
