# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    module CfdCharts
      def self.cfd(work_items, title: 'Cumulative Flow Diagram')
        data = VegaVisualizer.format_cfd_data(Calculators::Cfd.calculate(work_items))
        chart = Vega.lite.data(data).layer([VegaVisualizer.cfd_area_layer([], legend: false)])
        VegaVisualizer.apply_standard_dims(chart, title: title)
      end

      def self.forecasted_cfd(work_items, percentiles, title)
        data = Calculators::Cfd.forecast_series(work_items, percentiles: percentiles)
        return cfd(work_items, title: title) unless data

        unified = VegaVisualizer.build_cfd_unified_data(data, percentiles)
        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(unified)
              .layer([VegaVisualizer.cfd_area_layer(percentiles),
                      VegaVisualizer.cfd_line_layer(percentiles),
                      VegaVisualizer.cfd_vert_layer(data, percentiles)]),
          title: title
        )
      end
    end
  end
end
