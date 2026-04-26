# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    module BasicCharts
      def self.cycle_time_scatter(items, percentiles, title: 'Cycle Time Scatter Plot')
        completed = PredictabilityEngine.completed_items(items)
        data = completed.map do |i|
          { date: PredictabilityEngine.format_date(i.end_date), cycle_time: i.cycle_time, id: i.id }
        end
        pct_data = PredictabilityEngine.mapped_percentiles(items, percentiles)
        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(data + pct_data.map { |p| { type: p[:label], val: p[:val], p: p[:p] } })
              .layer([scatter_points_layer, scatter_rules_layer(pct_data)]),
          title: title
        )
      end

      def self.scatter_points_layer
        x_axis = VegaVisualizer.date_x_axis(title: 'Completion Date',
                                            minorTicks: true,
                                            tickCount: { interval: 'week' })
        { mark: { type: 'point', opacity: 0.6, size: 20 },
          encoding: { x: x_axis,
                      y: VegaVisualizer.quantitative_y_axis('cycle_time', title: 'Cycle Time (days)'),
                      color: { value: '#4c78a8' },
                      tooltip: [VegaVisualizer.item_id_tooltip_field,
                                { field: 'date', type: 'temporal', title: 'Completion Date' },
                                { field: 'cycle_time', type: 'quantitative', title: 'Cycle Time (days)' }] } }
      end

      def self.scatter_rules_layer(pct_data)
        count = pct_data.size
        palette = ['#72b7b2', '#e45756', '#b279a2', '#ff9da7', '#ad494a', '#8ca27a']
        # More distinct dash styles and thicker lines
        dash_map = { 50 => [], 75 => [8, 4], 85 => [4, 4], 95 => [2, 2], 98 => [1, 1] }
        width_map = { 50 => 1.5, 75 => 2, 85 => 2.5, 95 => 3, 98 => 3.5 }

        dash_condition = dash_map.map { |p, dash| { test: "datum.p == #{p}", value: dash } }
        width_condition = width_map.map { |p, w| { test: "datum.p == #{p}", value: w } }

        { transform: [{ filter: 'datum.type != null' }],
          mark: { type: 'rule' },
          encoding: { y: VegaVisualizer.quantitative_y_axis('val'),
                      strokeDash: { condition: dash_condition, value: [4, 4] },
                      strokeWidth: { condition: width_condition, value: 1 },
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
