# frozen_string_literal: true

require 'unicode_plot'

module PredictabilityEngine
  module TerminalVisualizer
    def self.cycle_time_scatter(work_items, title: 'Cycle Time Scatter Plot')
      completed = work_items.select(&:completed?).sort_by(&:end_date)
      return 'No completed items to plot.' if completed.empty?

      x = completed.map { |item| (item.end_date - completed.first.end_date).to_i }
      y = completed.map(&:cycle_time)

      plot = UnicodePlot.scatterplot(x, y, title: title,
                                           xlabel: "Days since #{completed.first.end_date}",
                                           ylabel: 'Cycle Time (days)')
      plot.render
    end

    def self.throughput_histogram(work_items, title: 'Throughput Histogram')
      daily_tp = Calculators::Throughput.daily(work_items).values
      return 'No throughput data to plot.' if daily_tp.empty?

      plot = UnicodePlot.histogram(daily_tp, title: title, xlabel: 'Items per day', ylabel: 'Frequency')
      plot.render
    end

    def self.cfd_plot(work_items, title: 'Cumulative Flow Diagram')
      cfd_data = Calculators::Cfd.calculate(work_items)
      return 'No CFD data to plot.' if cfd_data.empty?

      render_cfd_unicode_plot(cfd_data, title)
    end

    def self.forecasted_cfd_plot(work_items, title: 'Forecasted Cumulative Flow Diagram')
      cfd_data = Calculators::Cfd.calculate(work_items)
      return 'No CFD data to plot.' if cfd_data.empty?

      forecast = Calculators::Cfd.forecast_points(work_items)
      return render_cfd_unicode_plot(cfd_data, title) unless forecast

      render_forecasted_cfd_unicode(cfd_data, forecast, title)
    end

    def self.render_forecasted_cfd_unicode(cfd_data, forecast, title)
      start_date = cfd_data.first[:date]
      dates, arrived, departed = prepare_data(cfd_data, forecast, start_date)

      plot = UnicodePlot.lineplot(dates, arrived, title: title, name: 'Arrivals',
                                                  ylabel: 'Total Items',
                                                  xlabel: "Days since #{start_date}")
      UnicodePlot.lineplot!(plot, dates.take(cfd_data.size), departed.compact, name: 'Historical')

      add_forecast_lines(plot, start_date, forecast)
      plot.render
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
      %i[p50 p85 p95].each do |p|
        points = forecast[p]
        next unless points

        x = points.map { |pt| (pt[:date] - start_date).to_i }
        y = points.map { |pt| pt[:count] }
        UnicodePlot.lineplot!(plot, x, y, name: p.to_s)
      end
    end

    def self.render_cfd_unicode_plot(cfd_data, title)
      dates = cfd_data.map { |d| (d[:date] - cfd_data.first[:date]).to_i }
      plot = UnicodePlot.lineplot(dates, cfd_data.map { |d| d[:arrived] },
                                  title: title, name: 'Arrivals', ylabel: 'Total Items',
                                  xlabel: "Days since #{cfd_data.first[:date]}")
      UnicodePlot.lineplot!(plot, dates, cfd_data.map { |d| d[:departed] }, name: 'Departures')
      plot.render
    end
  end
end
