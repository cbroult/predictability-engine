# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    module BasicCharts
      def self.cycle_time_scatter(work_items, percentiles)
        completed = PredictabilityEngine.completed_items(work_items)
        data = completed.map { |i| { date: i.end_date.to_s, cycle_time: i.cycle_time, id: i.id } }
        pct_data = PredictabilityEngine.mapped_percentiles(work_items, percentiles)
        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(data + pct_data.map { |p| { type: p[:label], val: p[:val] } })
              .title('Cycle Time Scatter Plot')
              .layer([scatter_points_layer, scatter_rules_layer(pct_data.size)])
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
        data = Calculators::Throughput.daily(work_items).values.map { |v| { throughput: v } }
        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(data).title('Throughput Histogram').mark(type: 'bar', tooltip: true)
              .encoding(x: { field: 'throughput', type: 'quantitative', bin: true, title: 'Items per Day' },
                        y: { aggregate: 'count', type: 'quantitative', title: 'Frequency' })
        )
      end
    end
  end
end
