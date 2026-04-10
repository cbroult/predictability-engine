# frozen_string_literal: true

require 'vega'

module PredictabilityEngine
  module VegaVisualizer
    def self.cycle_time_scatter(work_items)
      data = work_items.select(&:completed?).map do |item|
        { date: item.end_date.to_s, cycle_time: item.cycle_time, id: item.id }
      end
      build_scatter_chart(data)
    end

    def self.build_scatter_chart(data)
      Vega.lite.data(data).title('Cycle Time Scatter Plot')
          .mark(type: 'point', tooltip: true)
          .encoding(x: { field: 'date', type: 'temporal', title: 'Completion Date' },
                    y: { field: 'cycle_time', type: 'quantitative', title: 'Cycle Time (days)' },
                    color: { value: '#4c78a8' })
          .width(600).height(400)
    end

    def self.throughput_histogram(work_items)
      daily_tp = Calculators::Throughput.daily(work_items).values
      data = daily_tp.map { |v| { throughput: v } }

      Vega.lite.data(data).title('Throughput Histogram').mark(type: 'bar', tooltip: true)
          .encoding(x: { field: 'throughput', type: 'quantitative', bin: true, title: 'Items per Day' },
                    y: { aggregate: 'count', type: 'quantitative', title: 'Frequency' })
          .width(600).height(400)
    end

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
      %i[p50 p85 p95].flat_map do |p|
        forecast[p].map { |pt| { date: pt[:date].to_s, count: pt[:count], type: p.to_s } }
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
                             scale: { domain: %w[Arrivals Departures p50 p85 p95],
                                      range: ['#4c78a8', '#f58518', '#72b7b2', '#e45756', '#b279a2'] } } } }
    end

    def self.line_layer
      { transform: [{ filter: "datum.type == 'p50' || datum.type == 'p85' || datum.type == 'p95'" }],
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

    def self.dashboard(work_items)
      scatter = cycle_time_scatter(work_items).spec.except('$schema')
      throughput = throughput_histogram(work_items).spec.except('$schema')
      cfd_chart = forecasted_cfd(work_items).spec.except('$schema')
      Vega.lite.vconcat([scatter, throughput, cfd_chart])
    end
  end
end
