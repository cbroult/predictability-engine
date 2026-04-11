# frozen_string_literal: true

require 'unicode_plot'
require 'stringio'

module PredictabilityEngine
  module TerminalVisualizer
    def self.aging_wip(work_items, color: false)
      data = Calculators::Aging.item_age_data(work_items)
      return 'No items currently in progress.' if data.empty?

      pcts = PredictabilityEngine.mapped_percentiles(work_items)
      plot = UnicodePlot.barplot(data.map { |d| d[:id].to_s }, data.map { |d| d[:age] },
                                 title: 'Aging Work In Progress (Days)', color: color ? :blue : nil)
      [plot.render, '', '--- SLE Benchmarks (Historical) ---',
       pcts.map { |p| "  #{p[:label]}: #{p[:val]} days" }.join("\n")].join("\n")
    end

    def self.cycle_time_scatter(work_items, title: 'Cycle Time Scatter Plot', color: false,
                                percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
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

    def self.throughput_histogram(work_items, title: 'Throughput Histogram', color: false)
      daily = Calculators::Throughput.daily(work_items).values
      return 'No throughput data to plot.' if daily.empty?

      plot = UnicodePlot.histogram(daily, title: title, xlabel: 'Items per day', ylabel: 'Frequency')
      render_to_string(plot, color: color)
    end

    def self.cfd_plot(work_items, title: 'Cumulative Flow Diagram', color: false)
      cfd = Calculators::Cfd.calculate(work_items)
      return 'No CFD data to plot.' if cfd.empty?

      start = cfd.first[:date]
      coords = Calculators::Cfd.to_coordinates(cfd, start)
      plot = lineplot_base(coords[:dates], coords[:arrived], title, start)
      UnicodePlot.lineplot!(plot, coords[:dates], coords[:departed], name: 'Departures')
      render_to_string(plot, color: color)
    end

    def self.forecasted_cfd_plot(work_items, title: 'Forecasted Cumulative Flow Diagram', color: false,
                                 percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      Calculators::Cfd.with_forecast(work_items, percentiles: percentiles) do |f|
        return cfd_plot(work_items, title: title, color: color) unless f

        cfd = Calculators::Cfd.calculate(work_items)
        start = cfd.first[:date]
        coords = Calculators::Cfd.to_coordinates(cfd, start)
        (1..f[:max_days]).each { |i| coords[:dates] << (Date.today + i - start).to_i }

        y_arr = coords[:arrived] + ([f[:summary][:total_items]] * f[:max_days])
        plot = lineplot_base(coords[:dates], y_arr, title, start)
        UnicodePlot.lineplot!(plot, coords[:dates].take(cfd.size), coords[:departed], name: 'Departures')
        add_terminal_forecast_lines(plot, start, f, percentiles)
        render_to_string(plot, color: color)
      end
    end

    def self.lineplot_base(x_coords, y_coords, title, start)
      UnicodePlot.lineplot(x_coords, y_coords, title: title, name: 'Arrivals', ylabel: 'Total Items',
                                               xlabel: "Days since #{start}")
    end

    def self.add_terminal_forecast_lines(plot, start, f, pcts)
      pcts.each do |p|
        pts = f[:"p#{p}"]
        next unless pts

        x = pts.map { |pt| (pt[:date] - start).to_i }
        UnicodePlot.lineplot!(plot, x, pts.map { |pt| pt[:count] }, name: "#{p}% Confidence")
        UnicodePlot.lineplot!(plot, [x.last, x.last], [0, f[:summary][:total_items]])
      end
    end

    def self.render_to_string(plot, color: false)
      out = StringIO.new
      plot.render(out, color: color)
      out.string
    end

    private_class_method :add_terminal_forecast_lines, :render_to_string, :lineplot_base
  end
end
