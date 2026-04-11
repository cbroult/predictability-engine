# frozen_string_literal: true

require 'vega'

module PredictabilityEngine
  module VegaVisualizer
    module CfdVisualizer
      def self.color_range
        ['#4c78a8', '#f58518', '#72b7b2', '#e45756', '#b279a2', '#ff9da7', '#ad494a', '#8ca27a']
      end

      def self.cfd_domain(percentiles)
        %w[Arrivals Departures] + percentiles.map { |p| "#{p}% Confidence" }
      end

      def self.forecast_filter(percentiles)
        percentiles.map { |p| "datum.type == '#{p}% Confidence'" }.join(' || ')
      end

      def self.cfd(work_items)
        cfd_data = Calculators::Cfd.calculate(work_items)
        data = format_cfd_data(cfd_data)
        build_cfd_chart(data, 'Cumulative Flow Diagram')
      end

      def self.build_cfd_chart(data, title)
        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(data).title(title)
              .layer([area_layer([], legend: false)])
        )
      end

      def self.forecasted_cfd(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        Calculators::Cfd.with_forecast(work_items, percentiles: percentiles) do |forecast|
          return cfd(work_items) unless forecast

          hist_data = format_cfd_data(Calculators::Cfd.calculate(work_items))
          extend_arrivals(hist_data, forecast)

          forecast_data = build_forecast_data(forecast, percentiles: percentiles)
          render_forecasted_cfd(hist_data, forecast_data, percentiles: percentiles)
        end
      end

      def self.extend_arrivals(hist_data, forecast)
        summ = forecast[:summary]
        max_date = summ[:today] + forecast[:max_days]
        hist_data << { date: max_date.to_s, count: summ[:total_items], type: 'Arrivals' }
      end

      def self.build_forecast_data(forecast, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        percentiles.flat_map do |p|
          label = "#{p}% Confidence"
          forecast[:"p#{p}"].map { |pt| { date: pt[:date].to_s, count: pt[:count], type: label } }
        end
      end

      def self.render_forecasted_cfd(hist_data, forecast_data, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(hist_data + forecast_data).title('Forecasted Cumulative Flow Diagram')
              .layer([area_layer(percentiles), line_layer(percentiles)])
        )
      end

      def self.area_layer(percentiles, legend: true)
        cfg = { field: 'type', type: 'nominal', scale: { domain: cfd_domain(percentiles), range: color_range } }
        cfg[:legend] = { title: 'Flow & Forecast' } if legend

        { mark: { type: 'area', line: true, tooltip: true },
          encoding: { x: { field: 'date', type: 'temporal', title: 'Date' },
                      y: { field: 'count', type: 'quantitative', title: 'Total Items', stack: nil },
                      color: cfg } }
      end

      def self.line_layer(percentiles)
        { transform: [{ filter: forecast_filter(percentiles) }],
          mark: { type: 'line', strokeDash: [4, 4], tooltip: true },
          encoding: { x: { field: 'date', type: 'temporal' },
                      y: { field: 'count', type: 'quantitative' },
                      color: { field: 'type', type: 'nominal' } } }
      end

      def self.format_cfd_data(cfd_data)
        cfd_data.flat_map do |d|
          [{ date: d[:date].to_s, count: d[:arrived], type: 'Arrivals' },
           { date: d[:date].to_s, count: d[:departed], type: 'Departures' }]
        end
      end
    end
  end
end
