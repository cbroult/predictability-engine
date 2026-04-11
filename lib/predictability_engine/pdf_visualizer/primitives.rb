# frozen_string_literal: true

module PredictabilityEngine
  module PdfVisualizer
    module Primitives
      def self.chart_width = 250
      def self.chart_height = 100

      def self.draw_line_chart(pdf, _labels, series)
        max_y = series.map { |s| s[:values].max }.max || 1

        draw_canvas(pdf) do
          series.each { |s| draw_series(pdf, s, series.first[:values].size, max_y) }
        end
        draw_legend(pdf, series)
      end

      def self.draw_series(pdf, series_data, labels_count, max_y)
        pdf.stroke_color series_data[:color]
        points = series_data[:values].each_with_index.map do |v, i|
          x = (i.to_f / (labels_count - 1)) * chart_width
          y = (v.to_f / max_y) * chart_height
          [x, y]
        end

        pdf.stroke do
          pdf.move_to(*points[0])
          points[1..].each { |p| pdf.line_to(*p) }
        end
      end

      def self.draw_legend(pdf, series)
        # Use smaller legend for dashboard
        series.each do |s|
          pdf.fill_color s[:color]
          pdf.fill_rectangle [0, pdf.cursor], 8, 8
          pdf.fill_color '000000'
          pdf.draw_text s[:label], at: [12, pdf.cursor - 6], size: 6
          pdf.move_down 10
        end
      end

      def self.draw_bar_chart(pdf, labels, values)
        max_y = values.max || 1
        bar_width = labels.empty? ? chart_width : chart_width / labels.size.to_f

        draw_canvas(pdf) do
          values.each_with_index do |v, i|
            h = (v.to_f / max_y) * chart_height
            pdf.fill_color '3366CC'
            pdf.fill_rectangle [i * bar_width, h], [bar_width - 2, 1].max, h
          end
        end
      end

      def self.draw_scatter_plot(pdf, labels, values)
        max_y = values.max || 1

        draw_canvas(pdf) do
          values.each_with_index do |v, i|
            x = labels.size <= 1 ? 0 : (i.to_f / (labels.size - 1)) * chart_width
            y = (v.to_f / max_y) * chart_height
            pdf.fill_circle [x, y], 1.5
          end
        end
      end

      def self.draw_canvas(pdf)
        pdf.bounding_box([0, pdf.cursor], width: chart_width, height: chart_height) do
          pdf.stroke_bounds
          yield
          pdf.stroke_color '000000'
          pdf.fill_color '000000'
        end
        pdf.move_down 5
      end
    end
  end
end
