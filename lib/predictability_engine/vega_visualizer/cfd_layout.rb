# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    # Layout and data logic for CFD charts in Vega-Lite.
    module CfdLayout
      def self.build_unified_data(data, percentiles)
        res = []
        sorted_pcts = percentiles.sort
        data[:dates].each_with_index do |date, i|
          res << { date: date.to_s, count: data[:arrivals][i], type: 'Arrivals', order: 0 }
          sorted_pcts.each_with_index do |p, pi|
            res << { date: date.to_s, count: data[:forecasts][p][i], type: "#{p}% Confidence", order: pi + 1 }
          end
          if i < data[:departed].size
            res << { date: date.to_s, count: data[:departed][i], type: 'Departures', order: sorted_pcts.size + 1 }
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
          encoding: { y: { field: 'count', type: 'quantitative', title: 'Total Items', stack: nil },
                      color: cfg,
                      order: { field: 'order', type: 'quantitative' } } }
      end

      def self.line_layer
        { mark: { type: 'line', tooltip: true },
          encoding: { y: { field: 'count', type: 'quantitative' },
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
          encoding: vert_encoding(y: { datum: 0 }, y2: quantitative_y)
        )
      end

      def self.text_layer(data)
        base_layer(data).merge(
          mark: { type: 'text', align: 'left', baseline: 'middle',
                  fontWeight: 'bold', fontSize: 10, angle: -45, dx: 5, tooltip: true },
          encoding: vert_encoding(y: quantitative_y, text: { field: 'label' })
        )
      end

      def self.vert_encoding(**opts)
        { x: temporal_x, tooltip: tooltip_field, color: { value: '#e45756' } }.merge(opts)
      end

      def self.base_layer(data)
        { data: { values: data } }
      end

      def self.temporal_x
        { field: 'date', type: 'temporal', timeUnit: 'utc-yearmonthdate' }
      end

      def self.quantitative_y
        { field: 'count', type: 'quantitative' }
      end

      def self.tooltip_field
        { field: 'tooltip', type: 'nominal' }
      end

      def self.vert_data(forecast, percentiles)
        sorted_pcts = percentiles.sort
        data_by_date = group_pcts_by_date(forecast, sorted_pcts)

        data_by_date.keys.sort.map do |date_str|
          p_list = data_by_date[date_str].sort
          forecast_val = calculate_forecast_at(forecast, date_str, p_list.first)

          { date: date_str, label: p_list.map { |p| "#{p}%" }.join(', '),
            tooltip: p_list.map { |p| "#{p}% Confidence (#{date_str})" }.join("\n"),
            count: forecast_val }
        end
      end

      def self.group_pcts_by_date(forecast, sorted_pcts)
        sorted_pcts.each_with_index.with_object({}) do |(p, i), h|
          target_p = i < sorted_pcts.size - 1 ? sorted_pcts[i + 1] : p
          days = forecast[:summary][:"p#{target_p}"]
          next unless days

          date_str = (forecast[:summary][:today] + days).to_s
          h[date_str] ||= []
          h[date_str] << p
        end
      end

      def self.calculate_forecast_at(forecast, date_str, percentile)
        idx = forecast[:dates].index { |d| d.to_s == date_str }
        idx ? forecast[:forecasts][percentile][idx] : forecast[:summary][:departed_so_far] + forecast[:summary][:wip]
      end

      private_class_method :rule_layer, :text_layer, :temporal_x, :quantitative_y, :tooltip_field,
                           :group_pcts_by_date, :calculate_forecast_at, :base_layer, :vert_encoding
    end
  end
end
