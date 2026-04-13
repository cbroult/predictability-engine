# frozen_string_literal: true

require 'vega'
require_relative 'vega_visualizer/basic_charts'
require_relative 'vega_visualizer/cfd_charts'
require_relative 'vega_visualizer/aging_wip_visualizer'
require_relative 'vega_visualizer/cfd_layout'

module PredictabilityEngine
  module VegaVisualizer
    CHART_WIDTH = 500
    CHART_HEIGHT = 300

    def self.apply_standard_dims(chart, title: nil)
      chart = chart.title(title) if title
      chart.width('container').height('container').config(
        autosize: { type: 'fit', contains: 'padding' },
        axis: { grid: false }
      )
    end

    def self.cycle_time_scatter(items, pcts: PredictabilityEngine::DEFAULT_PERCENTILES,
                                title: 'Cycle Time Scatter Plot', **)
      BasicCharts.cycle_time_scatter(items, pcts, title: title)
    end

    def self.throughput_histogram(items, title: 'Throughput Histogram', **)
      BasicCharts.throughput_histogram(items, title: title)
    end

    def self.aging_wip(items, title: 'Aging Work In Progress',
                       pcts: PredictabilityEngine::DEFAULT_PERCENTILES, **)
      AgingWipVisualizer.aging_wip(items, title: title, percentiles: pcts, **)
    end

    def self.cfd(work_items, title: 'Cumulative Flow Diagram', **_opts)
      CfdCharts.cfd(work_items, title: title)
    end

    def self.forecasted_cfd(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES,
                            title: 'Forecasted Cumulative Flow Diagram', **_opts)
      CfdCharts.forecasted_cfd(work_items, percentiles, title)
    end

    def self.build_cfd_unified_data(data, percentiles)
      CfdLayout.build_unified_data(data, percentiles)
    end

    def self.cfd_color_scale(pcts)
      CfdLayout.color_scale(pcts)
    end

    def self.cfd_area_layer(pcts, legend: true)
      CfdLayout.area_layer(pcts, legend: legend)
    end

    def self.cfd_line_layer(_pcts)
      CfdLayout.line_layer
    end

    def self.cfd_vert_layers(forecast, percentiles)
      CfdLayout.vert_layers(forecast, percentiles)
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
