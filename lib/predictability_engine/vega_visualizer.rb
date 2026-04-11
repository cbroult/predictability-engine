# frozen_string_literal: true

require 'vega'
require_relative 'vega_visualizer/basic_charts'

module PredictabilityEngine
  module VegaVisualizer
    CHART_WIDTH = 600
    CHART_HEIGHT = 400

    def self.apply_standard_dims(chart)
      chart.width(CHART_WIDTH).height(CHART_HEIGHT)
    end

    def self.cycle_time_scatter(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      BasicCharts.cycle_time_scatter(work_items, percentiles)
    end

    def self.throughput_histogram(work_items)
      BasicCharts.throughput_histogram(work_items)
    end

    def self.aging_wip(work_items)
      data = Calculators::Aging.item_age_data(work_items)
      return Vega.lite.data([]).title('Aging Work In Progress') if data.empty?

      pcts = PredictabilityEngine.mapped_percentiles(work_items)
      apply_standard_dims(
        Vega.lite.data(data).title('Aging Work In Progress')
            .layer([aging_bar_layer, *aging_rule_layers(pcts)])
      )
    end

    def self.aging_bar_layer
      { mark: { type: 'bar', tooltip: true },
        encoding: { x: { field: 'id', type: 'nominal', title: 'Work Item ID', sort: '-y' },
                    y: { field: 'age', type: 'quantitative', title: 'Age (days)' },
                    color: { field: 'age', type: 'quantitative', scale: { scheme: 'yelloworangered' } } } }
    end

    def self.aging_rule_layers(pcts)
      pcts.map do |p|
        { data: { values: [{ val: p[:val] }] },
          mark: { type: 'rule', strokeDash: [4, 4] },
          encoding: { y: { field: 'val', type: 'quantitative' },
                      color: { value: '#e45756' } } }
      end
    end

    def self.cfd(work_items)
      data = format_cfd_data(Calculators::Cfd.calculate(work_items))
      chart = Vega.lite.data(data).title('Cumulative Flow Diagram').layer([cfd_area_layer([], legend: false)])
      apply_standard_dims(chart)
    end

    def self.forecasted_cfd(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      Calculators::Cfd.with_forecast(work_items, percentiles: percentiles) do |f|
        return cfd(work_items) unless f

        hist = format_cfd_data(Calculators::Cfd.calculate(work_items))
        extend_cfd_arrivals(hist, f)
        f_data = build_cfd_forecast_data(f, percentiles)
        apply_standard_dims(
          Vega.lite.data(hist + f_data).title('Forecasted Cumulative Flow Diagram')
              .layer([cfd_area_layer(percentiles), cfd_line_layer(percentiles),
                      cfd_vert_layer(f, percentiles)])
        )
      end
    end

    def self.extend_cfd_arrivals(hist, f)
      hist << { date: (f[:summary][:today] + f[:max_days]).to_s, count: f[:summary][:total_items], type: 'Arrivals' }
    end

    def self.build_cfd_forecast_data(f, percentiles)
      percentiles.flat_map do |p|
        f[:"p#{p}"].map { |pt| { date: pt[:date].to_s, count: pt[:count], type: "#{p}% Confidence" } }
      end
    end

    def self.cfd_area_layer(pcts, legend: true)
      dom = %w[Arrivals Departures] + pcts.map { |p| "#{p}% Confidence" }
      range = ['#4c78a8', '#f58518', '#72b7b2', '#e45756', '#b279a2', '#ff9da7', '#ad494a', '#8ca27a']
      cfg = { field: 'type', type: 'nominal', scale: { domain: dom, range: range } }
      cfg[:legend] = { title: 'Flow & Forecast' } if legend
      { mark: { type: 'area', line: true, tooltip: true },
        encoding: { x: { field: 'date', type: 'temporal', title: 'Date' },
                    y: { field: 'count', type: 'quantitative', title: 'Total Items', stack: nil },
                    color: cfg } }
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
        [{ date: d[:date].to_s, count: d[:arrived], type: 'Arrivals' },
         { date: d[:date].to_s, count: d[:departed], type: 'Departures' }]
      end
    end

    def self.dashboard(items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      charts = [aging_wip(items), forecasted_cfd(items, percentiles: percentiles),
                cycle_time_scatter(items, percentiles: percentiles), throughput_histogram(items)]
      Vega.lite.vconcat(charts.map { |c| c.spec.except('$schema') })
    end
  end
end
