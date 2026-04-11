# frozen_string_literal: true

require 'unicode_plot'
require 'stringio'

module PredictabilityEngine
  module TerminalVisualizer
    def self.aging_wip(work_items, color: false, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES, **_opts)
      data = Calculators::Aging.item_age_data(work_items)
      return 'No items currently in progress.' if data.empty?

      pcts = PredictabilityEngine.mapped_percentiles(work_items, percentiles)
      plot = UnicodePlot.barplot(data.map { |d| d[:id].to_s }, data.map { |d| d[:age] },
                                 title: 'Aging Work In Progress (Days)', color: color ? :blue : nil)
      [plot.render, '', '--- SLE Benchmarks (Historical) ---',
       pcts.map { |p| "  #{p[:label]}: #{p[:val]} days" }.join("\n")].join("\n")
    end

    def self.cycle_time_scatter(work_items, title: 'Cycle Time Scatter Plot', color: false,
                                percentiles: PredictabilityEngine::DEFAULT_PERCENTILES, **_opts)
      completed = Calculators::CycleTime.completed_sorted(work_items)
      return 'No completed items to plot.' if completed.empty?

      start = completed.first.end_date
      x = completed.map { |i| (i.end_date - start).to_i }
      plot = UnicodePlot.scatterplot(x, completed.map(&:cycle_time), title: title,
                                                                     xlabel: "Days since #{start}",
                                                                     ylabel: 'Cycle Time (days)')
      PredictabilityEngine.mapped_percentiles(work_items, percentiles).each do |p|
        UnicodePlot.lineplot!(plot, x.minmax, [p[:val], p[:val]], name: p[:label])
      end
      render_to_string(plot, color: color)
    end

    def self.throughput_histogram(work_items, title: 'Throughput Histogram', color: false, **_opts)
      daily = Calculators::Throughput.daily(work_items).values
      return 'No throughput data to plot.' if daily.empty?

      plot = UnicodePlot.histogram(daily, title: title, xlabel: 'Items per day', ylabel: 'Frequency')
      render_to_string(plot, color: color)
    end

    def self.cfd_plot(work_items, title: 'Cumulative Flow Diagram', color: false, **_opts)
      cfd = Calculators::Cfd.calculate(work_items)
      return 'No CFD data to plot.' if cfd.empty?

      start = cfd.first[:date]
      coords = Calculators::Cfd.to_coordinates(cfd, start)
      plot = lineplot_base(coords[:dates], coords[:arrived], title, start)
      UnicodePlot.lineplot!(plot, coords[:dates], coords[:departed], name: 'Departures')
      render_to_string(plot, color: color)
    end

    def self.forecasted_cfd_plot(work_items, title: 'Forecasted Cumulative Flow Diagram', color: false,
                                 percentiles: PredictabilityEngine::DEFAULT_PERCENTILES, **_opts)
      data = Calculators::Cfd.forecast_series(work_items, percentiles: percentiles)
      return cfd_plot(work_items, title: title, color: color) unless data

      start = data[:dates].first
      x_coords = data[:dates].map { |d| (d - start).to_i }
      hist_size = data[:departed].size
      sorted_pcts = percentiles.sort

      plot = lineplot_base(x_coords, data[:arrivals], title, start)
      sorted_pcts.each do |p|
        UnicodePlot.lineplot!(plot, x_coords, data[:forecasts][p], name: "#{p}% Confidence")
        deadline_x = x_coords[hist_size - 1 + data[:summary][:"p#{p}"]]
        UnicodePlot.lineplot!(plot, [deadline_x, deadline_x], [0, data[:summary][:total_items]])
      end
      UnicodePlot.lineplot!(plot, x_coords.take(hist_size), data[:departed], name: 'Departures')

      render_to_string(plot, color: color)
    end

    def self.lineplot_base(x_coords, y_coords, title, start)
      UnicodePlot.lineplot(x_coords, y_coords, title: title, name: 'Arrivals', ylabel: 'Total Items',
                                               xlabel: "Days since #{start}")
    end

    def self.render_to_string(plot, color: false)
      sio = StringIO.new
      plot.render(sio, color: color)
      sio.string
    end

    private_class_method :lineplot_base, :render_to_string
  end
end
