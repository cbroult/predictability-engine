# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    # Layout and data logic for CFD charts in Vega-Lite.
    module CfdLayout
      def self.build_unified_data(data, percentiles)
        res = []
        sorted_pcts = percentiles.sort
        data[:dates].each_with_index do |date, i|
          res << { date: PredictabilityEngine.format_date(date), count: data[:arrivals][i], type: 'Arrivals', order: 0 }
          sorted_pcts.each_with_index do |p, pi|
            res << { date: PredictabilityEngine.format_date(date), count: data[:forecasts][p][i],
                     type: "#{p}% Confidence", order: pi + 1 }
          end
          if i < data[:departed].size
            res << { date: PredictabilityEngine.format_date(date), count: data[:departed][i], type: 'Departures',
                     order: sorted_pcts.size + 1 }
          end
        end
        res
      end

      def self.color_scale(pcts)
        sorted_pcts = pcts.sort
        dom = ['Arrivals'] + sorted_pcts.map { |p| "#{p}% Confidence" } + ['Departures']
        palette = ['#72b7b2', '#e45756', '#b279a2', '#ff9da7', '#ad494a', '#8ca27a']
        range = ['#4c78a8'] + palette.take(sorted_pcts.size) + ['#59a14f']
        [dom, range]
      end

      def self.area_layer(pcts, legend: true)
        cfg = { field: 'type', type: 'nominal' }
        cfg[:legend] = { title: 'Flow & Forecast', orient: 'bottom', columns: 3 } if legend && !pcts.empty?
        { mark: { type: 'area', tooltip: true },
          encoding: { y: VegaVisualizer.quantitative_y_axis('count', title: 'Total Items', stack: nil),
                      color: cfg,
                      order: { field: 'order', type: 'quantitative' } } }
      end

      def self.line_layer
        { mark: { type: 'line', tooltip: true },
          encoding: { y: VegaVisualizer.quantitative_y_axis('count'),
                      strokeDash: {
                        condition: { test: "datum.type == 'Arrivals' || datum.type == 'Departures'", value: [] },
                        value: [4, 4]
                      } } }
      end

      def self.vert_layers(forecast, percentiles)
        data = vert_data(forecast, percentiles)
        [
          rule_layer(data),
          text_layer(data)
        ]
      end

      def self.rule_layer(data)
        base_layer(data).merge(
          mark: { type: 'rule', strokeDash: [4, 2], strokeWidth: 2, tooltip: true },
          encoding: vert_encoding(y: { datum: 0 }, y2: VegaVisualizer.quantitative_y_axis('count', title: nil))
        )
      end

      def self.text_layer(data)
        base_layer(data).merge(
          mark: { type: 'text', align: 'left', baseline: 'middle',
                  fontWeight: 'bold', fontSize: 10, angle: -45, dx: 5, tooltip: true },
          encoding: vert_encoding(y: VegaVisualizer.quantitative_y_axis('count', title: nil), text: { field: 'label' })
        )
      end

      def self.vert_encoding(**opts)
        { x: VegaVisualizer.date_axis_base, tooltip: tooltip_field, color: { value: '#e45756' } }.merge(opts)
      end

      def self.base_layer(data)
        { data: { values: data } }
      end

      def self.tooltip_field
        { field: 'tooltip', type: 'nominal' }
      end

      def self.vert_data(forecast, percentiles)
        sorted_pcts = percentiles.sort
        data_by_date = group_pcts_by_date(forecast, sorted_pcts)

        # IMMUTABLE invariant — see CLAUDE.md §"Forecast alignment invariant".
        # Rule height = percentile-surface plateau (departed_so_far + wip), so each
        # vertical rule hits the top-right corner of its p% surface exactly.
        plateau = forecast[:summary][:departed_so_far] + forecast[:summary][:wip]

        data_by_date.sort_by { |date, _| date }.map do |date, p_list|
          date_str = PredictabilityEngine.format_date(date)
          label = "#{p_list.sort.map { |p| "#{p}%" }.join(', ')} (#{date_str})"

          { date: date_str, label: label,
            tooltip: p_list.map { |p| "#{p}% Confidence (#{date_str})" }.join("\n"),
            count: plateau }
        end
      end

      def self.group_pcts_by_date(forecast, sorted_pcts)
        groups = []
        today = forecast[:summary][:today]

        sorted_pcts.each do |p|
          days = forecast[:summary][:"p#{p}"]
          next unless days

          date = today + days

          # Collision avoidance: if date is close to an existing group, add to it
          # Threshold: 2 days seems reasonable for collision avoidance
          matched_group = groups.find { |g| (g[:date] - date).abs <= 2 }
          if matched_group
            matched_group[:pcts] << p
          else
            groups << { date: date, pcts: [p] }
          end
        end

        groups.to_h { |g| [PredictabilityEngine.format_date(g[:date]), g[:pcts]] }
      end

      private_class_method :rule_layer, :text_layer, :tooltip_field,
                           :group_pcts_by_date, :base_layer, :vert_encoding
    end
  end
end
