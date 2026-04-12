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
      chart.width('container').height('container').config(
        autosize: { type: 'fit', contains: 'padding' },
        axis: { grid: false }
      )
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

    def self.cfd_color_scale(pcts)
      sorted_pcts = pcts.sort
      dom = ['Arrivals'] + sorted_pcts.map { |p| "#{p}% Confidence" } + ['Departures']
      palette = ['#72b7b2', '#e45756', '#b279a2', '#ff9da7', '#ad494a', '#8ca27a']
      range = ['#4c78a8'] + palette.take(sorted_pcts.size) + ['#59a14f']
      [dom, range]
    end

    def self.cfd_area_layer(pcts, legend: true)
      cfg = { field: 'type', type: 'nominal' }
      if legend && !pcts.empty?
        cfg[:legend] = { title: 'Flow & Forecast', orient: 'bottom', columns: 3 }
      end
      { mark: { type: 'area', tooltip: true },
        encoding: { y: { field: 'count', type: 'quantitative', title: 'Total Items', stack: nil },
                    color: cfg,
                    order: { field: 'order', type: 'quantitative' } } }
    end

    def self.cfd_line_layer(_pcts)
      # Lines for all types, but with dash for forecasts
      { mark: { type: 'line', tooltip: true },
        encoding: { y: { field: 'count', type: 'quantitative' },
                    strokeDash: {
                      condition: { test: "datum.type == 'Arrivals' || datum.type == 'Departures'", value: [] },
                      value: [4, 4]
                    } } }
    end

    def self.cfd_vert_layers(f, pcts)
      data = cfd_vert_data(f, pcts)
      [
        { data: { values: data },
          mark: { type: 'rule', strokeDash: [4, 2], color: '#e45756', strokeWidth: 2, tooltip: true },
          encoding: { x: { field: 'date', type: 'temporal', timeUnit: 'utc-yearmonthdate' },
                      y: { datum: 0 },
                      y2: { field: 'total_items', type: 'quantitative' },
                      tooltip: { field: 'tooltip', type: 'nominal' } } },
        { data: { values: data },
          mark: { type: 'text', color: '#e45756', align: 'left', baseline: 'middle',
                  fontWeight: 'bold', fontSize: 10, angle: -45, dx: 5, tooltip: true },
          encoding: { x: { field: 'date', type: 'temporal', timeUnit: 'utc-yearmonthdate' },
                      y: { field: 'total_items', type: 'quantitative' },
                      text: { field: 'label' },
                      tooltip: { field: 'tooltip', type: 'nominal' } } }
      ]
    end

    def self.cfd_vert_data(f, pcts)
      data_by_date = pcts.each_with_object({}) do |p, h|
        d = f[:summary][:today] + f[:summary][:"p#{p}"]
        date_str = d.to_s
        h[date_str] ||= []
        h[date_str] << p
      end

      sorted_dates = data_by_date.keys.sort
      sorted_dates.map do |date_str|
        p_list = data_by_date[date_str].sort
        label = p_list.map { |p| "#{p}%" }.join(", ")
        
        # Use the forecast count for rule height to hit the surface's top-right corner
        idx = f[:dates].index { |d| d.to_s == date_str }
        # All percentiles in p_list reached their goal on this date
        forecast_val = idx ? f[:forecasts][p_list.first][idx] : f[:summary][:departed_so_far] + f[:summary][:wip]

        { date: date_str,
          label: label,
          tooltip: p_list.map { |p| "#{p}% Confidence (#{date_str})" }.join("\n"),
          total_items: forecast_val }
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
