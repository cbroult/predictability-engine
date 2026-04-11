# frozen_string_literal: true

require 'date'

module PredictabilityEngine
  module Calculators
    module Cfd
      def self.calculate(work_items, start_date: nil, end_date: nil)
        arrival_data = work_items.map { |i| { date: i.start_date, type: :arrived } }
        departure_data = work_items.select(&:completed?).map { |i| { date: i.end_date, type: :departed } }
        events = (arrival_data + departure_data).sort_by { |e| e[:date] }
        return [] if events.empty?

        results = process_events(events)
        fill_daily_gaps(results, start_date, end_date)
      end

      def self.fill_daily_gaps(results, start_date, end_date)
        start_date ||= results.first[:date]
        end_date ||= results.last[:date]

        data_map = results.to_h { |r| [r[:date], r] }
        arrived = 0
        departed = 0

        (start_date..end_date).map do |date|
          if data_map[date]
            arrived = data_map[date][:arrived]
            departed = data_map[date][:departed]
          end
          { date: date, arrived: arrived, departed: departed, wip: arrived - departed }
        end
      end

      def self.process_events(events)
        arrived = 0
        departed = 0
        results = []
        events.group_by { |e| e[:date] }.each do |date, day_events|
          day_events.each { |e| e[:type] == :arrived ? arrived += 1 : departed += 1 }
          results << { date: date, arrived: arrived, departed: departed, wip: arrived - departed }
        end
        results
      end

      def self.forecast_summary(work_items, trials: 10_000, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        backlog = work_items.reject(&:completed?).size
        historical = Throughput.daily(work_items).values
        return nil if backlog.zero? || historical.empty?

        results = Simulators::MonteCarlo.when_will_it_be_done(backlog, historical, trials: trials)
        res = { wip: backlog, today: Date.today, total_items: work_items.size,
                departed_so_far: work_items.count(&:completed?) }
        percentiles.each { |p| res[:"p#{p}"] = Simulators::MonteCarlo.percentile(results, p) }
        res
      end

      def self.forecast_series(work_items, trials: 10_000, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        cfd_data = calculate(work_items, end_date: Date.today)
        return nil if cfd_data.empty?

        summary = forecast_summary(work_items, trials: trials, percentiles: percentiles)
        return nil unless summary

        history = cfd_data.last(15)
        max_days = percentiles.map { |p| summary[:"p#{p}"] }.max || 0
        { dates: build_dates(history, max_days), arrivals: build_arrivals(history, max_days),
          departed: history.map { |d| d[:departed] }, summary: summary, max_days: max_days,
          forecasts: build_forecast_map(history, summary, max_days, percentiles) }
      end

      def self.build_dates(history, max_days)
        dates = history.map { |d| d[:date] }
        (1..max_days).each { |i| dates << (history.last[:date] + i) }
        dates
      end

      def self.build_arrivals(history, max_days)
        arrivals = history.map { |d| d[:arrived] }
        (1..max_days).each { |_i| arrivals << history.last[:arrived] }
        arrivals
      end

      def self.build_forecast_map(history, summary, max_days, percentiles)
        percentiles.each_with_object({}) do |p, h|
          days = summary[:"p#{p}"]
          res = history.map { |d| d[:departed] }
          (1..max_days).each do |i|
            point = if i <= days
                      (history.last[:departed] + (i * (summary[:wip].to_f / days))).round
                    else
                      summary[:total_items]
                    end
            res << point
          end
          h[p] = res
        end
      end

      def self.with_forecast(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        forecast = forecast_summary(work_items, percentiles: percentiles)
        return yield(nil) unless forecast

        yield({ summary: forecast, max_days: percentiles.map { |p| forecast[:"p#{p}"] }.max })
      end

      def self.to_coordinates(cfd, start_date)
        { dates: cfd.map { |d| (d[:date] - start_date).to_i },
          arrived: cfd.map { |d| d[:arrived] },
          departed: cfd.map { |d| d[:departed] } }
      end

      private_class_method :process_events, :build_dates, :build_arrivals, :build_forecast_map, :fill_daily_gaps
    end
  end
end
