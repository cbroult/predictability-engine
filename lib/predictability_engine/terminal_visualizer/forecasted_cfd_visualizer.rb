# frozen_string_literal: true

require 'unicode_plot'

module PredictabilityEngine
  module TerminalVisualizer
    module ForecastedCfdVisualizer
      def self.plot(work_items, title: TerminalVisualizer::DEFAULT_FORECAST_TITLE, color: false,
                    percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        cfd_data = TerminalVisualizer.load_and_validate_cfd(work_items)
        return cfd_data if cfd_data.is_a?(String)

        Calculators::Cfd.with_forecast(work_items, percentiles: percentiles) do |forecast|
          return TerminalVisualizer.render_cfd_unicode_plot(cfd_data, title, color: color) unless forecast

          render_forecasted_cfd_unicode(cfd_data, forecast, title, color: color, percentiles: percentiles)
        end
      end

      def self.render_forecasted_cfd_unicode(cfd_data, forecast, title, color: false,
                                             percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        start_date = cfd_data.first[:date]
        dates, arrived, departed = prepare_data(cfd_data, forecast, start_date, percentiles)

        plot = TerminalVisualizer.base_cfd_plot(dates, arrived, title, start_date)
        UnicodePlot.lineplot!(plot, dates.take(cfd_data.size), departed.compact, name: 'Departures')

        add_forecast_lines(plot, start_date, forecast, percentiles)
        TerminalVisualizer.render_to_string(plot, color: color)
      end

      def self.prepare_data(cfd_data, forecast, start_date, _percentiles)
        dates, arrived, departed = TerminalVisualizer.extract_cfd_arrays(cfd_data, start_date)
        extend_data({ dates: dates, arrived: arrived, departed: departed }, forecast, start_date)
        [dates, arrived, departed]
      end

      def self.extend_data(arrays, forecast, start_date)
        summ = forecast[:summary]
        (1..forecast[:max_days]).each do |i|
          arrays[:dates] << (Date.today + i - start_date).to_i
          arrays[:arrived] << summ[:total_items]
          arrays[:departed] << nil
        end
      end

      def self.add_forecast_lines(plot, start_date, forecast, percentiles)
        percentiles.each do |p|
          label = "#{p}% Confidence"
          points = forecast[:"p#{p}"]
          next unless points

          x = points.map { |pt| (pt[:date] - start_date).to_i }
          y = points.map { |pt| pt[:count] }
          UnicodePlot.lineplot!(plot, x, y, name: label)
        end
      end

      private_class_method :render_forecasted_cfd_unicode, :prepare_data,
                           :extend_data, :add_forecast_lines
    end
  end
end
