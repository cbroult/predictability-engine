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

    def self.date_axis_base(title: 'Date')
      { field: 'date', type: 'temporal', title: title, axis: { format: '%Y-%m-%d' } }
    end

    def self.date_x_axis(title: 'Date', **opts)
      base = date_axis_base(title: title)
      base[:axis] = base[:axis].merge(labelAngle: -45).merge(opts)
      base
    end

    def self.quantitative_y_axis(...) = quantitative_axis(...)
    def self.quantitative_x_axis(...) = quantitative_axis(...)

    def self.quantitative_axis(field, title: :auto, **opts)
      res = { field: field.to_s, type: 'quantitative' }
      res[:title] = title == :auto ? field.to_s.capitalize : title
      res.merge(opts)
    end
    private_class_method :quantitative_axis

    def self.cycle_time_scatter(items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES,
                                title: 'Cycle Time Scatter Plot', **)
      BasicCharts.cycle_time_scatter(items, percentiles, title: title)
    end

    def self.throughput_histogram(items, title: 'Throughput Histogram', **)
      BasicCharts.throughput_histogram(items, title: title)
    end

    def self.aging_wip(items, title: 'Aging Work In Progress',
                       percentiles: PredictabilityEngine::DEFAULT_PERCENTILES, **)
      AgingWipVisualizer.aging_wip(items, title: title, percentiles: percentiles, **)
    end

    def self.cfd(work_items, title: 'Cumulative Flow Diagram', history_range: nil, **_opts)
      CfdCharts.cfd(work_items, title: title, history_range: history_range)
    end

    def self.forecasted_cfd(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES,
                            title: 'Forecasted Cumulative Flow Diagram', history_range: nil, **_opts)
      CfdCharts.forecasted_cfd(work_items, percentiles, title, history_range: history_range)
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
        [{ date: PredictabilityEngine.format_date(d[:date]), count: d[:arrived], type: 'Arrivals', order: 0 },
         { date: PredictabilityEngine.format_date(d[:date]), count: d[:departed], type: 'Departures', order: 1 }]
      end
    end

    def self.dashboard(items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      charts = [aging_wip(items), forecasted_cfd(items, percentiles: percentiles), cfd(items),
                cycle_time_scatter(items, percentiles: percentiles),
                throughput_histogram(items)]
      Vega.lite.vconcat(charts.map { |c| c.spec.except('$schema') })
    end
  end
end
