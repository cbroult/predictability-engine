# frozen_string_literal: true

module PredictabilityEngine
  module PdfVisualizer
    CHART_WIDTH = 400
    CHART_HEIGHT = 150

    def self.draw_chart(pdf, chart_id, work_items)
      case chart_id
      when :cfd_plot, :forecasted_cfd_plot then draw_cfd(pdf, work_items)
      when :throughput_histogram then draw_throughput(pdf, work_items)
      when :cycle_time_scatter then draw_scatter(pdf, work_items)
      end
    end

    def self.draw_cfd(pdf, work_items)
      cfd_data = Calculators::Cfd.calculate(work_items)
      data = cfd_data.last(30)
      dates = data.map { |d| d[:date].to_s }
      series = [
        { label: 'Arrivals', values: data.map { |d| d[:arrived] }, color: '0000FF' },
        { label: 'Departures', values: data.map { |d| d[:departed] }, color: '00FF00' }
      ]
      draw_line_chart(pdf, dates, series)
    end

    def self.draw_throughput(pdf, work_items)
      counts = Calculators::Throughput.daily(work_items).values.tally.sort
      labels = counts.map { |k, _v| k.to_s }
      values = counts.map { |_k, v| v }

      draw_bar_chart(pdf, labels, values)
    end

    def self.draw_scatter(pdf, work_items)
      data = PredictabilityEngine.completed_items(work_items)
                                 .map { |i| [i.end_date.to_s, i.cycle_time] }.sort

      draw_scatter_plot(pdf, data.map(&:first), data.map { |d| d[1] })
    end

    def self.draw_line_chart(pdf, labels, series)
      max_y = series.map { |s| s[:values].max }.max || 1

      draw_canvas(pdf) do
        series.each { |s| draw_series(pdf, s, labels.size, max_y) }
      end
      draw_legend(pdf, series)
    end

    def self.draw_series(pdf, series_data, labels_count, max_y)
      pdf.stroke_color series_data[:color]
      points = series_data[:values].each_with_index.map do |v, i|
        x = (i.to_f / (labels_count - 1)) * CHART_WIDTH
        y = (v.to_f / max_y) * CHART_HEIGHT
        [x, y]
      end

      pdf.stroke do
        pdf.move_to(*points[0])
        points[1..].each { |p| pdf.line_to(*p) }
      end
    end

    def self.draw_legend(pdf, series)
      series.each do |s|
        pdf.fill_color s[:color]
        pdf.fill_rectangle [50, pdf.cursor], 10, 10
        pdf.fill_color '000000'
        pdf.draw_text s[:label], at: [65, pdf.cursor - 8], size: 8
        pdf.move_down 12
      end
    end

    def self.draw_bar_chart(pdf, labels, values)
      max_y = values.max || 1
      bar_width = begin
        CHART_WIDTH / labels.size.to_f
      rescue StandardError
        CHART_WIDTH
      end

      draw_canvas(pdf) do
        values.each_with_index do |v, i|
          h = (v.to_f / max_y) * CHART_HEIGHT
          pdf.fill_color '3366CC'
          pdf.fill_rectangle [i * bar_width, h], bar_width - 2, h
        end
      end
    end

    def self.draw_scatter_plot(pdf, labels, values)
      max_y = values.max || 1

      draw_canvas(pdf) do
        values.each_with_index do |v, i|
          x = begin
            (i.to_f / (labels.size - 1)) * CHART_WIDTH
          rescue StandardError
            0
          end
          y = (v.to_f / max_y) * CHART_HEIGHT
          pdf.fill_circle [x, y], 2
        end
      end
    end

    def self.draw_canvas(pdf)
      pdf.bounding_box([50, pdf.cursor], width: CHART_WIDTH, height: CHART_HEIGHT) do
        pdf.stroke_bounds
        yield
        pdf.stroke_color '000000'
        pdf.fill_color '000000'
      end
      pdf.move_down 10
    end

    private_class_method :draw_line_chart, :draw_bar_chart, :draw_scatter_plot, :draw_series, :draw_legend, :draw_canvas
  end
end
