# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    module CfdCharts
      def self.cfd(work_items, title: 'Cumulative Flow Diagram')
        data = VegaVisualizer.format_cfd_data(Calculators::Cfd.calculate(work_items))
        dom, range = VegaVisualizer.cfd_color_scale([])
        chart = Vega.lite.data(data)
                    .encoding(
                      x: { field: 'date', type: 'temporal', title: 'Date', timeUnit: 'utc-yearmonthdate' },
                      color: { field: 'type', type: 'nominal', scale: { domain: dom, range: range } }
                    )
                    .layer([VegaVisualizer.cfd_area_layer([], legend: false)])
        VegaVisualizer.apply_standard_dims(chart, title: title)
      end

      def self.forecasted_cfd(work_items, percentiles, title)
        data = Calculators::Cfd.forecast_series(work_items, percentiles: percentiles)
        return cfd(work_items, title: title) unless data

        unified = VegaVisualizer.build_cfd_unified_data(data, percentiles)
        dom, range = VegaVisualizer.cfd_color_scale(percentiles)

        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(unified)
              .layer([
                { mark: { type: 'area', tooltip: true },
                  encoding: {
                    x: { field: 'date', type: 'temporal', title: 'Date', timeUnit: 'utc-yearmonthdate' },
                    y: { field: 'count', type: 'quantitative', title: 'Total Items', stack: nil, scale: { zero: false } },
                    color: { field: 'type', type: 'nominal', scale: { domain: dom, range: range },
                             legend: { title: 'Flow & Forecast', orient: 'bottom', columns: 4 } },
                    order: { field: 'order', type: 'quantitative' }
                  }
                },
                { mark: { type: 'line', tooltip: true },
                  encoding: {
                    x: { field: 'date', type: 'temporal', timeUnit: 'utc-yearmonthdate' },
                    y: { field: 'count', type: 'quantitative' },
                    color: { field: 'type', type: 'nominal', legend: nil },
                    strokeDash: {
                      condition: { test: "datum.type == 'Arrivals' || datum.type == 'Departures'", value: [] },
                      value: [4, 4]
                    }
                  }
                },
                *VegaVisualizer.cfd_vert_layers(data, percentiles)
              ]),
          title: title
        )
      end
    end
  end
end
