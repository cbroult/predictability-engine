# frozen_string_literal: true

require 'vega'
require_relative 'vega_visualizer/basic_charts'
require_relative 'vega_visualizer/cfd_charts'
require_relative 'vega_visualizer/aging_wip_visualizer'

module PredictabilityEngine
  module VegaVisualizer
    CHART_WIDTH = 500
    CHART_HEIGHT = 300

    def self.apply_standard_dims(chart, title: nil)
      chart = chart.title(title) if title
      chart.width(CHART_WIDTH).height(CHART_HEIGHT).config(autosize: { type: 'fit', contains: 'padding' })
    end

    def self.cycle_time_scatter(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES,
                                title: 'Cycle Time Scatter Plot', **_opts)
      BasicCharts.cycle_time_scatter(work_items, percentiles, title: title)
    end

    def self.throughput_histogram(work_items, title: 'Throughput Histogram', **_opts)
      BasicCharts.throughput_histogram(work_items, title: title)
    end

    def self.aging_wip(work_items, title: 'Aging Work In Progress',
                       percentiles: PredictabilityEngine::DEFAULT_PERCENTILES, **)
      AgingWipVisualizer.aging_wip(work_items, title: title, percentiles: percentiles, **)
    end

    def self.cfd(work_items, title: 'Cumulative Flow Diagram', **_opts)
      CfdCharts.cfd(work_items, title: title)
    end

    def self.forecasted_cfd(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES,
                            title: 'Forecasted Cumulative Flow Diagram', **_opts)
      CfdCharts.forecasted_cfd(work_items, percentiles, title)
    end

    def self.build_cfd_unified_data(data, percentiles)
      res = []
      sorted_pcts = percentiles.sort
      data[:dates].each_with_index do |date, i|
        # Arrivals (drawn first, bottom)
        res << { date: date.to_s, count: data[:arrivals][i], type: 'Arrivals', order: 0 }
        # Forecasts (drawn middle)
        sorted_pcts.each_with_index do |p, pi|
          res << { date: date.to_s, count: data[:forecasts][p][i], type: "#{p}% Confidence", order: pi + 1 }
        end
        # Departures (drawn last, top-most)
        if i < data[:departed].size
          res << { date: date.to_s, count: data[:departed][i], type: 'Departures', order: sorted_pcts.size + 1 }
        end
      end
      res
    end

    def self.cfd_area_layer(pcts, legend: true)
      sorted_pcts = pcts.sort
      dom = %w[Arrivals Departures] + sorted_pcts.map { |p| "#{p}% Confidence" }
      palette = ['#72b7b2', '#e45756', '#b279a2', '#ff9da7', '#ad494a', '#8ca27a']
      range = ['#4c78a8', '#59a14f'] + palette.take(sorted_pcts.size)
      cfg = { field: 'type', type: 'nominal', scale: { domain: dom, range: range } }
      if legend
        # Use the original pcts order for the legend if it differs from sorted
        cfg[:legend] = { title: 'Flow & Forecast', orient: 'bottom', columns: 4 }
        if pcts != sorted_pcts
          cfg[:legend][:values] = %w[Arrivals Departures] + pcts.map do |p|
            "#{p}% Confidence"
          end
        end
      end
      { mark: { type: 'area', line: true, tooltip: true },
        encoding: { x: { field: 'date', type: 'temporal', title: 'Date' },
                    y: { field: 'count', type: 'quantitative', title: 'Total Items', stack: nil },
                    color: cfg,
                    order: { field: 'order', type: 'quantitative' } } }
    end

    def self.cfd_line_layer(pcts)
      filter = pcts.map { |p| "datum.type == '#{p}% Confidence'" }.join(' || ')
      { transform: [{ filter: filter }], mark: { type: 'line', strokeDash: [4, 4], tooltip: true },
        encoding: { x: { field: 'date', type: 'temporal' }, y: { field: 'count', type: 'quantitative' },
                    color: { field: 'type', type: 'nominal' } } }
    end

    def self.cfd_vert_layer(f, pcts)
      { data: { values: cfd_vert_data(f, pcts) }, mark: { type: 'rule', strokeDash: [2, 2], color: '#666' },
        encoding: { x: { field: 'date', type: 'temporal' }, tooltip: { field: 'tooltip', type: 'nominal' } } }
    end

    def self.cfd_vert_data(f, pcts)
      pcts.map do |p|
        d = f[:summary][:today] + f[:summary][:"p#{p}"]
        { date: d.to_s, label: "#{p}%", tooltip: "#{p}% Confidence (#{d})" }
      end
    end

    def self.format_cfd_data(cfd)
      cfd.flat_map do |d|
        [{ date: d[:date].to_s, count: d[:arrived], type: 'Arrivals', order: 0 },
         { date: d[:date].to_s, count: d[:departed], type: 'Departures', order: 1 }]
      end
    end

    def self.dashboard(items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      charts = [aging_wip(items), forecasted_cfd(items, percentiles: percentiles),
                cycle_time_scatter(items, percentiles: percentiles), throughput_histogram(items)]
      Vega.lite.vconcat(charts.map { |c| c.spec.except('$schema') })
    end
  end
end
