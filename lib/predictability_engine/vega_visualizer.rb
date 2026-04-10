# frozen_string_literal: true

require 'vega'

module PredictabilityEngine
  module VegaVisualizer
    def self.cycle_time_scatter(work_items)
      completed = work_items.select(&:completed?)
      data = completed.map do |item|
        { date: item.end_date.to_s, cycle_time: item.cycle_time, id: item.id }
      end

      percentiles = [50, 85, 95].map do |p|
        val = Calculators::CycleTime.percentile(work_items, p)
        { val: val, label: "#{p}% Percentile (#{val} d)" } if val
      end.compact

      build_scatter_chart(data, percentiles)
    end

    def self.build_scatter_chart(data, percentiles)
      Vega.lite.data(data + percentiles.map { |p| { type: p[:label], val: p[:val] } })
          .title('Cycle Time Scatter Plot')
          .layer([scatter_points_layer, scatter_rules_layer])
          .width(600).height(400)
    end

    def self.scatter_points_layer
      { mark: { type: 'point', tooltip: true },
        encoding: { x: { field: 'date', type: 'temporal', title: 'Completion Date' },
                    y: { field: 'cycle_time', type: 'quantitative', title: 'Cycle Time (days)' },
                    color: { value: '#4c78a8' } } }
    end

    def self.scatter_rules_layer
      { transform: [{ filter: 'datum.type != null' }],
        mark: { type: 'rule', strokeDash: [4, 4] },
        encoding: { y: { field: 'val', type: 'quantitative' },
                    color: { field: 'type', type: 'nominal', title: 'Percentiles',
                             scale: { range: ['#72b7b2', '#e45756', '#b279a2'] } } } }
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
      CfdVisualizer.cfd(work_items)
    end

    def self.forecasted_cfd(work_items)
      CfdVisualizer.forecasted_cfd(work_items)
    end

    def self.dashboard(work_items)
      scatter = cycle_time_scatter(work_items).spec.except('$schema')
      throughput = throughput_histogram(work_items).spec.except('$schema')
      cfd_chart = forecasted_cfd(work_items).spec.except('$schema')
      Vega.lite.vconcat([scatter, throughput, cfd_chart])
    end
  end
end
