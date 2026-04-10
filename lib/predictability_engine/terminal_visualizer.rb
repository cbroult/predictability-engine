# frozen_string_literal: true

require 'unicode_plot'
require 'stringio'

module PredictabilityEngine
  module TerminalVisualizer
    def self.cycle_time_scatter(work_items, title: 'Cycle Time Scatter Plot', color: false)
      completed = work_items.select(&:completed?).sort_by(&:end_date)
      return 'No completed items to plot.' if completed.empty?

      start_date = completed.first.end_date
      x_coords = completed.map { |item| (item.end_date - start_date).to_i }
      y_coords = completed.map(&:cycle_time)

      plot = render_scatter_plot(x_coords, y_coords, title, start_date)
      add_scatter_percentiles(plot, work_items, x_coords.min, x_coords.max)
      render_to_string(plot, color: color)
    end

    def self.render_scatter_plot(x_coords, y_coords, title, start_date)
      UnicodePlot.scatterplot(x_coords, y_coords, title: title,
                                                  xlabel: "Days since #{start_date}",
                                                  ylabel: 'Cycle Time (days)')
    end

    def self.add_scatter_percentiles(plot, work_items, x_min, x_max)
      { 50 => '50% Percentile', 85 => '85% Percentile', 95 => '95% Percentile' }.each do |p, label|
        val = Calculators::CycleTime.percentile(work_items, p)
        next unless val

        UnicodePlot.lineplot!(plot, [x_min, x_max], [val, val], name: label)
      end
    end

    def self.throughput_histogram(work_items, title: 'Throughput Histogram', color: false)
      daily_tp = Calculators::Throughput.daily(work_items).values
      return 'No throughput data to plot.' if daily_tp.empty?

      plot = UnicodePlot.histogram(daily_tp, title: title, xlabel: 'Items per day', ylabel: 'Frequency')
      render_to_string(plot, color: color)
    end

    def self.cfd_plot(work_items, title: 'Cumulative Flow Diagram', color: false)
      cfd_data = Calculators::Cfd.calculate(work_items)
      return 'No CFD data to plot.' if cfd_data.empty?

      render_cfd_unicode_plot(cfd_data, title, color: color)
    end

    def self.forecasted_cfd_plot(work_items, title: 'Forecasted Cumulative Flow Diagram', color: false)
      cfd_data = Calculators::Cfd.calculate(work_items)
      return 'No CFD data to plot.' if cfd_data.empty?

      forecast = Calculators::Cfd.forecast_points(work_items)
      return render_cfd_unicode_plot(cfd_data, title, color: color) unless forecast

      render_forecasted_cfd_unicode(cfd_data, forecast, title, color: color)
    end

    def self.render_forecasted_cfd_unicode(cfd_data, forecast, title, color: false)
      start_date = cfd_data.first[:date]
      dates, arrived, departed = prepare_data(cfd_data, forecast, start_date)

      plot = UnicodePlot.lineplot(dates, arrived, title: title, name: 'Arrivals',
                                                  ylabel: 'Total Items',
                                                  xlabel: "Days since #{start_date}")
      UnicodePlot.lineplot!(plot, dates.take(cfd_data.size), departed.compact, name: 'Departures')

      add_forecast_lines(plot, start_date, forecast)
      render_to_string(plot, color: color)
    end

    def self.prepare_data(cfd_data, forecast, start_date)
      dates = cfd_data.map { |d| (d[:date] - start_date).to_i }
      arrived = cfd_data.map { |d| d[:arrived] }
      departed = cfd_data.map { |d| d[:departed] }

      extend_data(dates, arrived, departed, forecast, start_date)
      [dates, arrived, departed]
    end

    def self.extend_data(dates, arrived, departed, forecast, start_date)
      summ = forecast[:summary]
      max_days = [summ[:p50], summ[:p85], summ[:p95]].compact.max || 0
      (1..max_days).each do |i|
        dates << (Date.today + i - start_date).to_i
        arrived << summ[:total_items]
        departed << nil
      end
    end

    def self.add_forecast_lines(plot, start_date, forecast)
      { p50: '50% Confidence', p85: '85% Confidence', p95: '95% Confidence' }.each do |p, label|
        points = forecast[p]
        next unless points

        x = points.map { |pt| (pt[:date] - start_date).to_i }
        y = points.map { |pt| pt[:count] }
        UnicodePlot.lineplot!(plot, x, y, name: label)
      end
    end

    def self.render_cfd_unicode_plot(cfd_data, title, color: false)
      dates = cfd_data.map { |d| (d[:date] - cfd_data.first[:date]).to_i }
      plot = UnicodePlot.lineplot(dates, cfd_data.map { |d| d[:arrived] },
                                  title: title, name: 'Arrivals', ylabel: 'Total Items',
                                  xlabel: "Days since #{cfd_data.first[:date]}")
      UnicodePlot.lineplot!(plot, dates, cfd_data.map { |d| d[:departed] }, name: 'Departures')
      render_to_string(plot, color: color)
    end

    def self.render_to_string(plot, color: false)
      out = StringIO.new
      plot.render(out, color: color)
      out.string
    end
  end
end
