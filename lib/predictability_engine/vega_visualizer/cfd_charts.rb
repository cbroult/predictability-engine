# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    module CfdCharts
      def self.cfd(work_items, title: 'Cumulative Flow Diagram', history_range: nil)
        data = Calculators::Cfd.calculate(work_items)
        days = Duration.parse(history_range)
        data = data.last(days) if days
        formatted = VegaVisualizer.format_cfd_data(data)
        render_cfd(formatted, [], title)
      end

      def self.forecasted_cfd(work_items, percentiles, title, history_range: nil)
        data = Calculators::Cfd.forecast_series(work_items, percentiles: percentiles, history_range: history_range)
        return cfd(work_items, title: title) unless data

        unified = VegaVisualizer.build_cfd_unified_data(data, percentiles)
        render_cfd(unified, percentiles, title, forecast: data)
      end

      def self.render_cfd(data, percentiles, title, forecast: nil)
        dom, range = VegaVisualizer.cfd_color_scale(percentiles)
        chart = base_cfd_chart(data, dom, range)
                .layer(cfd_layers(percentiles, forecast))
        resolved_title = forecast ? forecast_title(title) : title
        padding = forecast ? { right: 110 } : nil
        VegaVisualizer.apply_standard_dims(chart, title: resolved_title, padding: padding)
      end

      def self.forecast_title(text)
        { text: text,
          subtitle: [
            'Each X% Confidence surface = forecast of cumulative departures if backlog completes at that confidence',
            '(Monte Carlo on historical throughput; NOT cycle-time percentile bands)'
          ] }
      end

      def self.cfd_layers(percentiles, forecast)
        layers = [VegaVisualizer.cfd_area_layer(percentiles, legend: !percentiles.empty?)]
        return layers unless forecast

        layers + [VegaVisualizer.cfd_line_layer(percentiles),
                  *VegaVisualizer.cfd_vert_layers(forecast, percentiles)]
      end

      def self.base_cfd_chart(data, dom, range)
        # Find last day to ensure it can be labeled
        dates = data.map { |d| PredictabilityEngine.format_date(d[:date]) }.compact.uniq.sort
        first_date = Date.parse(dates.first)
        last_date = Date.parse(dates.last)

        # Major ticks every week, starting from first_date, plus exactly last_date
        major_ticks = []
        curr = first_date
        while curr < last_date
          major_ticks << PredictabilityEngine.format_date(curr)
          curr += 7
        end
        major_ticks << PredictabilityEngine.format_date(last_date)
        major_ticks.uniq!

        # Use axis options directly in date_x_axis to avoid hash merge overwrite
        Vega.lite.data(data)
            .encoding(
              x: VegaVisualizer.date_x_axis(
                values: major_ticks,
                labelFlush: true,
                labelOverlap: 'parity',
                minorTicks: true,
                tickSize: 8,
                minorTickSize: 4
              ),
              y: VegaVisualizer.quantitative_y_axis('count', title: 'Total Items'),
              color: { field: 'type', type: 'nominal', scale: { domain: dom, range: range } }
            )
      end

      private_class_method :base_cfd_chart, :forecast_title
    end
  end
end
