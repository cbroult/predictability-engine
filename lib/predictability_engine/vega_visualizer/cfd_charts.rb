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
        Calculators::Cfd.with_forecast(work_items, percentiles: percentiles) do |f|
          return cfd(work_items, title: title) unless f

          hist = VegaVisualizer.format_cfd_data(Calculators::Cfd.calculate(work_items))
          VegaVisualizer.extend_cfd_arrivals(hist, f)
          f_data = VegaVisualizer.build_cfd_forecast_data(f, percentiles)
          VegaVisualizer.apply_standard_dims(
            Vega.lite.data(hist + f_data)
                .layer([VegaVisualizer.cfd_area_layer(percentiles), VegaVisualizer.cfd_line_layer(percentiles),
                        VegaVisualizer.cfd_vert_layer(f, percentiles)]),
            title: title
          )
        end
      end
    end
  end
end
