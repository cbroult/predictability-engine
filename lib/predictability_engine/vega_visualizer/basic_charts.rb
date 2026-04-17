# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    module BasicCharts
      def self.cycle_time_scatter(items, pcts, title: 'Cycle Time Scatter Plot')
        completed = PredictabilityEngine.completed_items(items)
        data = completed.map { |i| { date: i.end_date.to_s, cycle_time: i.cycle_time, id: i.id } }
        pct_data = PredictabilityEngine.mapped_percentiles(items, pcts)
        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(data + pct_data.map { |p| { type: p[:label], val: p[:val] } })
              .layer([scatter_points_layer, scatter_rules_layer(pct_data.size)]),
          title: title
        )
      end

      def self.scatter_points_layer
        { mark: { type: 'point', tooltip: true, opacity: 0.6, size: 20 },
          encoding: { x: VegaVisualizer.date_x_axis(title: 'Completion Date'),
                      y: VegaVisualizer.quantitative_y_axis('cycle_time', title: 'Cycle Time (days)'),
                      color: { value: '#4c78a8' } } }
      end

      def self.scatter_rules_layer(count)
        palette = ['#72b7b2', '#e45756', '#b279a2', '#ff9da7', '#ad494a', '#8ca27a']
        { transform: [{ filter: 'datum.type != null' }],
          mark: { type: 'rule', strokeDash: [4, 4] },
          encoding: { y: VegaVisualizer.quantitative_y_axis('val'),
                      color: { field: 'type', type: 'nominal', title: 'Percentiles',
                               scale: { range: palette.take(count) },
                               legend: { orient: 'bottom', columns: 3 } } } }
      end

      def self.throughput_histogram(items, title: 'Throughput Histogram')
        data = Calculators::Throughput.daily(items).values.map { |v| { throughput: v } }
        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(data).mark(type: 'bar', tooltip: true)
              .encoding(x: VegaVisualizer.quantitative_x_axis('throughput', bin: true, title: 'Items per Day'),
                        y: VegaVisualizer.quantitative_y_axis('count', aggregate: 'count', title: 'Frequency')),
          title: title
        )
      end
    end
  end
end
