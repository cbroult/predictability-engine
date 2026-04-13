# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    module CfdCharts
      def self.cfd(work_items, title: 'Cumulative Flow Diagram')
        data = Calculators::Cfd.calculate(work_items)
        formatted = VegaVisualizer.format_cfd_data(data)
        render_cfd(formatted, [], title)
      end

      def self.forecasted_cfd(work_items, percentiles, title)
        data = Calculators::Cfd.forecast_series(work_items, percentiles: percentiles)
        return cfd(work_items, title: title) unless data

        unified = VegaVisualizer.build_cfd_unified_data(data, percentiles)
        render_cfd(unified, percentiles, title, forecast: data)
      end

      def self.render_cfd(data, percentiles, title, forecast: nil)
        dom, range = VegaVisualizer.cfd_color_scale(percentiles)
        chart = base_cfd_chart(data, dom, range)
                .layer(cfd_layers(percentiles, forecast))
        VegaVisualizer.apply_standard_dims(chart, title: title)
      end

      def self.cfd_layers(percentiles, forecast)
        layers = [VegaVisualizer.cfd_area_layer(percentiles, legend: !percentiles.empty?)]
        return layers unless forecast

        layers + [VegaVisualizer.cfd_line_layer(percentiles),
                  *VegaVisualizer.cfd_vert_layers(forecast, percentiles)]
      end

      def self.base_cfd_chart(data, dom, range)
        Vega.lite.data(data)
            .encoding(
              x: { field: 'date', type: 'temporal', title: 'Date', timeUnit: 'utc-yearmonthdate' },
              y: { field: 'count', type: 'quantitative', title: 'Total Items' },
              color: { field: 'type', type: 'nominal', scale: { domain: dom, range: range } }
            )
      end

      private_class_method :base_cfd_chart
    end
  end
end
