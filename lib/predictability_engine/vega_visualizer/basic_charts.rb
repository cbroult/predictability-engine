# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    module BasicCharts
      def self.cycle_time_scatter(items, percentiles, title: 'Cycle Time Scatter Plot')
        completed = PredictabilityEngine.completed_items(items)
        data = completed.map do |i|
          { date: PredictabilityEngine.format_date(i.end_date), cycle_time: i.cycle_time, id: i.id,
            title: i.title, title_display: VegaVisualizer.wrap_tooltip_title(i.title) }
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
                                            tickCount: { interval: 'week' })
        { mark: { type: 'point', opacity: 0.6, size: 20 },
          encoding: { x: x_axis,
                      y: VegaVisualizer.quantitative_y_axis('cycle_time', title: 'Cycle Time (days)'),
                      color: { value: '#4c78a8' },
                      tooltip: VegaVisualizer.standard_item_tooltip_fields +
                        [{ field: 'date', type: 'temporal', title: 'Completion Date' },
                         VegaVisualizer.cycle_time_tooltip_field] } }
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
          encoding: { y: VegaVisualizer.quantitative_y_axis('val', title: 'Cycle Time (days)'),
                      strokeDash: { condition: dash_condition, value: [4, 4] },
                      strokeWidth: { condition: width_condition, value: 1 },
                      color: { field: 'type', type: 'nominal', title: 'Percentiles',
                               scale: { range: palette.take(count) },
                               legend: { orient: 'bottom', columns: 3 } },
                      tooltip: [{ field: 'type', type: 'nominal', title: 'Percentile' },
                                VegaVisualizer.cycle_time_tooltip_field(field: 'val')] } }
      end

      def self.throughput_histogram(items, title: 'Throughput Histogram')
        data = Calculators::Throughput.daily(items).values.map { |v| { throughput: v } }
        bar_chart(data, title: title,
                        x: VegaVisualizer.quantitative_x_axis('throughput', bin: true, title: 'Items per Day'),
                        y: VegaVisualizer.quantitative_y_axis('count', aggregate: 'count', title: 'Frequency'))
      end

      BAND_COLORS = %w[#2ca02c #98df8a #ffdd57 #ff7f0e #d62728 #7b0000].freeze

      GRANULARITY_PARAM = {
        name: 'granularity',
        value: 'yearweek',
        bind: { input: 'select',
                options: %w[yearday yearweek yearmonth],
                labels: %w[Daily Weekly Monthly],
                name: 'Group by: ' }
      }.freeze

      PERIOD_EXPR = "granularity === 'yearmonth' ? datum.date_month : " \
                    "(granularity === 'yearday' ? datum.date : datum.date_week)"

      def self.cycle_time_bands(items, title: 'Cycle Time Bands Over Time', **)
        labels = RawDataExporter::DONE_THRESHOLD_LABELS
        completed = PredictabilityEngine.completed_items(items)
        return Vega.lite.data([]).title(title) if completed.empty?

        data = completed.map do |item|
          idx = RawDataExporter.threshold_index(item.cycle_time)
          { date: PredictabilityEngine.format_date(item.end_date),
            date_week: PredictabilityEngine.format_year_week(item.end_date),
            date_month: PredictabilityEngine.format_year_month(item.end_date),
            band: labels[idx], band_order: idx }
        end
        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(data)
              .params([GRANULARITY_PARAM])
              .transform([{ calculate: PERIOD_EXPR, as: 'period' }])
              .mark(type: 'area', tooltip: true)
              .encoding(
                x: { field: 'period', type: 'ordinal', sort: 'ascending',
                     title: nil, axis: { labelAngle: -45, labelOverlap: 'parity' } },
                y: { aggregate: 'count', type: 'quantitative', title: 'Items Completed' },
                color: { field: 'band', type: 'ordinal', sort: labels,
                         scale: { domain: labels, range: BAND_COLORS },
                         legend: { title: 'Cycle Time', orient: 'bottom', columns: labels.size } },
                order: { field: 'band_order', type: 'quantitative' }
              ),
          title: title
        )
      end

      def self.bar_chart(data, title:, **encoding)
        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(data).mark(type: 'bar', tooltip: true).encoding(**encoding),
          title: title
        )
      end

      private_class_method :bar_chart
    end
  end
end
