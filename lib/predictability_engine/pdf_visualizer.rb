# frozen_string_literal: true

require_relative 'pdf_visualizer/primitives'

module PredictabilityEngine
  module PdfVisualizer
    def self.draw_chart(pdf, chart_id, work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      case chart_id
      when :cfd_plot then draw_cfd(pdf, work_items)
      when :forecasted_cfd_plot then draw_forecasted_cfd(pdf, work_items, percentiles: percentiles)
      when :throughput_histogram then draw_throughput(pdf, work_items)
      when :cycle_time_scatter then draw_scatter(pdf, work_items, percentiles: percentiles)
      when :aging_wip then draw_aging(pdf, work_items, percentiles: percentiles)
      end
    end

    def self.draw_aging(pdf, work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      data = Calculators::Aging.item_age_data(work_items)
      Primitives.draw_bar_chart(pdf, data.map { |d| d[:id].to_s }, data.map { |d| d[:age] })
    end

    def self.draw_cfd(pdf, work_items)
      cfd_data = Calculators::Cfd.calculate(work_items).last(30)
      series = [
        { label: 'Arrivals', values: cfd_data.map { |d| d[:arrived] }, color: '0000FF' },
        { label: 'Departures', values: cfd_data.map { |d| d[:departed] }, color: '00FF00' }
      ]
      Primitives.draw_line_chart(pdf, cfd_data.map { |d| d[:date].to_s }, series)
    end

    def self.draw_throughput(pdf, work_items)
      counts = Calculators::Throughput.histogram_data(work_items)
      Primitives.draw_bar_chart(pdf, counts.map { |k, _v| k.to_s }, counts.map { |_k, v| v })
    end

    def self.draw_scatter(pdf, work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      data = Calculators::CycleTime.completed_sorted(work_items)
                                   .map { |i| [i.end_date.to_s, i.cycle_time] }

      Primitives.draw_scatter_plot(pdf, data.map(&:first), data.map { |d| d[1] })

      pcts = PredictabilityEngine.mapped_percentiles(work_items, percentiles)
      pdf.move_down 10
      pdf.text "Percentiles: #{pcts.map { |p| "#{p[:label]}: #{p[:val]}" }.join(', ')}", size: 8
    end

    def self.draw_forecasted_cfd(pdf, work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      data = Calculators::Cfd.forecast_series(work_items, percentiles: percentiles)
      return draw_cfd(pdf, work_items) unless data

      series = [
        { label: 'Arrivals', values: data[:arrivals], color: '0000FF' },
        { label: 'Departures', values: data[:departed], color: '00FF00' }
      ]

      f_colors = %w[E6B800 CC0000 800080 008080 333333] # Darker versions of yellow, red, magenta, cyan, gray
      percentiles.sort.each_with_index do |p, i|
        # Slice for PDF as well if possible, though draw_line_chart might expect full series
        # For now, let's at least fix colors.
        series << { label: "#{p}% Conf.", values: data[:forecasts][p], color: f_colors[i % f_colors.size] }
      end

      Primitives.draw_line_chart(pdf, data[:dates].map(&:to_s), series)
    end
  end
end
