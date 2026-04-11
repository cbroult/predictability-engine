# frozen_string_literal: true

require 'unicode_plot'
require 'stringio'

module PredictabilityEngine
  module TerminalVisualizer
    DEFAULT_CFD_TITLE = 'Cumulative Flow Diagram'
    DEFAULT_FORECAST_TITLE = 'Forecasted Cumulative Flow Diagram'

    def self.cycle_time_scatter(work_items, title: 'Cycle Time Scatter Plot', color: false,
                                percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      completed = PredictabilityEngine.completed_items(work_items).sort_by(&:end_date)
      return 'No completed items to plot.' if completed.empty?

      start_date = completed.first.end_date
      x_coords = completed.map { |item| (item.end_date - start_date).to_i }
      y_coords = completed.map(&:cycle_time)

      plot = render_scatter_plot(x_coords, y_coords, title, start_date)
      add_scatter_percentiles(plot, work_items, x_coords.min, x_coords.max, percentiles)
      render_to_string(plot, color: color)
    end

    def self.render_scatter_plot(x_coords, y_coords, title, start_date)
      UnicodePlot.scatterplot(x_coords, y_coords, title: title,
                                                  xlabel: "Days since #{start_date}",
                                                  ylabel: 'Cycle Time (days)')
    end

    def self.add_scatter_percentiles(plot, work_items, x_min, x_max, percentiles)
      percentiles.each do |p|
        val = PredictabilityEngine.cycle_time_percentile(work_items, p)
        next unless val

        UnicodePlot.lineplot!(plot, [x_min, x_max], [val, val], name: "#{p}% Percentile")
      end
    end

    def self.throughput_histogram(work_items, title: 'Throughput Histogram', color: false)
      daily_tp = Calculators::Throughput.daily(work_items).values
      return 'No throughput data to plot.' if daily_tp.empty?

      plot = UnicodePlot.histogram(daily_tp, title: title, xlabel: 'Items per day', ylabel: 'Frequency')
      render_to_string(plot, color: color)
    end

    def self.cfd_plot(work_items, title: DEFAULT_CFD_TITLE, color: false)
      cfd_data = load_and_validate_cfd(work_items)
      return cfd_data if cfd_data.is_a?(String)

      render_cfd_unicode_plot(cfd_data, title, color: color)
    end

    def self.forecasted_cfd_plot(work_items, title: DEFAULT_FORECAST_TITLE, color: false,
                                 percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      ForecastedCfdVisualizer.plot(work_items, title: title, color: color, percentiles: percentiles)
    end

    def self.load_and_validate_cfd(work_items)
      cfd_data = Calculators::Cfd.calculate(work_items)
      cfd_data.empty? ? 'No CFD data to plot.' : cfd_data
    end

    def self.render_cfd_unicode_plot(cfd_data, title, color: false)
      start_date = cfd_data.first[:date]
      dates, arrived, departed = extract_cfd_arrays(cfd_data, start_date)

      plot = base_cfd_plot(dates, arrived, title, start_date)
      UnicodePlot.lineplot!(plot, dates, departed, name: 'Departures')
      render_to_string(plot, color: color)
    end

    def self.extract_cfd_arrays(cfd_data, start_date)
      [
        cfd_data.map { |d| (d[:date] - start_date).to_i },
        cfd_data.map { |d| d[:arrived] },
        cfd_data.map { |d| d[:departed] }
      ]
    end

    def self.base_cfd_plot(dates, arrived, title, start_date)
      UnicodePlot.lineplot(dates, arrived, title: title, name: 'Arrivals',
                                           ylabel: 'Total Items',
                                           xlabel: "Days since #{start_date}")
    end

    def self.render_to_string(plot, color: false)
      out = StringIO.new
      plot.render(out, color: color)
      out.string
    end
  end
end
