# frozen_string_literal: true

require 'date'

module PredictabilityEngine
  module Calculators
    module Cfd
      def self.calculate(work_items, start_date: nil, end_date: nil)
        arrival_data = work_items.map { |i| { date: i.start_date || i.end_date || Date.today, type: :arrived } }
        departure_data = work_items.select(&:completed?).map { |i| { date: i.end_date, type: :departed } }
        events = (arrival_data + departure_data).sort_by { |e| [e[:date], e[:type] == :arrived ? 0 : 1] }
        return [] if events.empty?

        results = process_events(events)
        fill_daily_gaps(results, start_date, end_date)
      end

      def self.forecast_summary(work_items, trials: 10_000, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        CfdForecaster.forecast_summary(work_items, trials: trials, percentiles: percentiles)
      end

      def self.forecast_series(work_items, trials: 10_000, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        CfdForecaster.forecast_series(work_items, trials: trials, percentiles: percentiles)
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

      private_class_method :process_events, :fill_daily_gaps
    end
  end
end
