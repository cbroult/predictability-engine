# frozen_string_literal: true

require 'vega'

module PredictabilityEngine
  module VegaVisualizer
    CHART_WIDTH = 600
    CHART_HEIGHT = 400

    def self.cycle_time_scatter(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      completed = PredictabilityEngine.completed_items(work_items)
      data = completed.map do |item|
        { date: item.end_date.to_s, cycle_time: item.cycle_time, id: item.id }
      end

      percentile_data = percentiles.map do |p|
        val = PredictabilityEngine.cycle_time_percentile(work_items, p)
        { val: val, label: "#{p}% Percentile (#{val} d)" } if val
      end.compact

      build_scatter_chart(data, percentile_data)
    end

    def self.apply_standard_dims(chart)
      chart.width(CHART_WIDTH).height(CHART_HEIGHT)
    end

    def self.build_scatter_chart(data, percentiles)
      apply_standard_dims(
        Vega.lite.data(data + percentiles.map { |p| { type: p[:label], val: p[:val] } })
            .title('Cycle Time Scatter Plot')
            .layer([scatter_points_layer, scatter_rules_layer(percentiles.size)])
      )
    end

    def self.scatter_points_layer
      { mark: { type: 'point', tooltip: true },
        encoding: { x: { field: 'date', type: 'temporal', title: 'Completion Date' },
                    y: { field: 'cycle_time', type: 'quantitative', title: 'Cycle Time (days)' },
                    color: { value: '#4c78a8' } } }
    end

    def self.scatter_rules_layer(count)
      range = ['#72b7b2', '#e45756', '#b279a2', '#ff9da7', '#ad494a', '#8ca27a']
      { transform: [{ filter: 'datum.type != null' }],
        mark: { type: 'rule', strokeDash: [4, 4] },
        encoding: { y: { field: 'val', type: 'quantitative' },
                    color: { field: 'type', type: 'nominal', title: 'Percentiles',
                             scale: { range: range.take(count) } } } }
    end

    def self.throughput_histogram(work_items)
      daily_tp = Calculators::Throughput.daily(work_items).values
      data = daily_tp.map { |v| { throughput: v } }

      apply_standard_dims(
        Vega.lite.data(data).title('Throughput Histogram').mark(type: 'bar', tooltip: true)
            .encoding(x: { field: 'throughput', type: 'quantitative', bin: true, title: 'Items per Day' },
                      y: { aggregate: 'count', type: 'quantitative', title: 'Frequency' })
      )
    end

    def self.cfd(work_items)
      CfdVisualizer.cfd(work_items)
    end

    def self.forecasted_cfd(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      CfdVisualizer.forecasted_cfd(work_items, percentiles: percentiles)
    end

    def self.dashboard(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      scatter = cycle_time_scatter(work_items, percentiles: percentiles).spec.except('$schema')
      throughput = throughput_histogram(work_items).spec.except('$schema')
      cfd_chart = forecasted_cfd(work_items, percentiles: percentiles).spec.except('$schema')
      Vega.lite.vconcat([scatter, throughput, cfd_chart])
    end
  end
end
