# frozen_string_literal: true

require 'vega'

module PredictabilityEngine
  module VegaVisualizer
    module CfdVisualizer
      COLOR_RANGE = ['#4c78a8', '#f58518', '#72b7b2', '#e45756', '#b279a2'].freeze
      CFD_DOMAIN = [
        'Arrivals', 'Departures', '50% Confidence', '85% Confidence', '95% Confidence'
      ].freeze
      FORECAST_FILTER = [
        "datum.type == '50% Confidence'",
        "datum.type == '85% Confidence'",
        "datum.type == '95% Confidence'"
      ].join(' || ').freeze

      def self.cfd(work_items)
        cfd_data = Calculators::Cfd.calculate(work_items)
        data = format_cfd_data(cfd_data)
        build_cfd_chart(data, 'Cumulative Flow Diagram')
      end

      def self.build_cfd_chart(data, title)
        Vega.lite.data(data).title(title).mark(type: 'area', line: true, tooltip: true)
            .encoding(x: { field: 'date', type: 'temporal', title: 'Date' },
                      y: { field: 'count', type: 'quantitative', title: 'Total Items', stack: nil },
                      color: { field: 'type', type: 'nominal', scale: { range: ['#4c78a8', '#f58518'] } })
            .width(600).height(400)
      end

      def self.forecasted_cfd(work_items)
        forecast = Calculators::Cfd.forecast_points(work_items)
        return cfd(work_items) unless forecast

        hist_data = format_cfd_data(Calculators::Cfd.calculate(work_items))
        extend_arrivals(hist_data, forecast)

        forecast_data = build_forecast_data(forecast)
        render_forecasted_cfd(hist_data, forecast_data)
      end

      def self.extend_arrivals(hist_data, forecast)
        summ = forecast[:summary]
        max_date = summ[:today] + [summ[:p50], summ[:p85], summ[:p95]].max
        hist_data << { date: max_date.to_s, count: summ[:total_items], type: 'Arrivals' }
      end

      def self.build_forecast_data(forecast)
        { p50: '50% Confidence', p85: '85% Confidence', p95: '95% Confidence' }.flat_map do |p, label|
          forecast[p].map { |pt| { date: pt[:date].to_s, count: pt[:count], type: label } }
        end
      end

      def self.render_forecasted_cfd(hist_data, forecast_data)
        Vega.lite.data(hist_data + forecast_data).title('Forecasted Cumulative Flow Diagram')
            .layer([area_layer, line_layer]).width(600).height(400)
      end

      def self.area_layer
        { mark: { type: 'area', line: true, tooltip: true },
          encoding: { x: { field: 'date', type: 'temporal', title: 'Date' },
                      y: { field: 'count', type: 'quantitative', title: 'Total Items', stack: nil },
                      color: { field: 'type', type: 'nominal',
                               scale: { domain: CFD_DOMAIN, range: COLOR_RANGE },
                               legend: { title: 'Flow & Forecast' } } } }
      end

      def self.line_layer
        { transform: [{ filter: FORECAST_FILTER }],
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
