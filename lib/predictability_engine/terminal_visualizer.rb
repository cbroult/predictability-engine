# frozen_string_literal: true

require 'unicode_plot'
require 'stringio'
require_relative 'terminal_visualizer/cfd_renderer'

module PredictabilityEngine
  module TerminalVisualizer
    def self.aging_wip(items, color: false, pcts: DEFAULT_PERCENTILES, **)
      age_data = Calculators::Aging.item_age_data(items)
      return 'No items currently in progress.' if age_data.empty?

      PredictabilityEngine.mapped_percentiles(items, pcts)
      plot = UnicodePlot.barplot(age_data.map { |d| d[:id].to_s }, age_data.map { |d| d[:age] },
                                 title: 'Aging Work In Progress (Days)', color: color ? :blue : nil)
      render_to_string(plot, color: color)
    end

    def self.cycle_time_scatter(items, title: 'Cycle Time Scatter Plot', color: false,
                                pcts: DEFAULT_PERCENTILES, **)
      completed = Calculators::CycleTime.completed_sorted(items)
      return 'No completed items to plot.' if completed.empty?

      start = completed.first.end_date
      x = completed.map { |i| (i.end_date - start).to_i }
      xlabel = "Days since #{PredictabilityEngine.format_date(start)}"
      plot = UnicodePlot.scatterplot(x, completed.map(&:cycle_time), title: title,
                                                                     xlabel: xlabel,
                                                                     ylabel: 'Cycle Time (days)')
      PredictabilityEngine.mapped_percentiles(items, pcts).each do |p|
        UnicodePlot.lineplot!(plot, x.minmax, [p[:val], p[:val]], name: p[:label])
      end
      render_to_string(plot, color: color)
    end

    def self.throughput_histogram(items, title: 'Throughput Histogram', color: false, **)
      daily = Calculators::Throughput.daily(items).values
      return 'No throughput data to plot.' if daily.empty?

      plot = UnicodePlot.histogram(daily, title: title, xlabel: 'Items per day', ylabel: 'Frequency')
      render_to_string(plot, color: color)
    end

    def self.cycle_time_bands(items, title: 'Cycle Time Bands Over Time', color: false, **)
      completed = PredictabilityEngine.completed_items(items)
      return 'No completed items to plot.' if completed.empty?

      labels = RawDataExporter::DONE_THRESHOLD_LABELS
      counts = Array.new(labels.size, 0)
      completed.each { |item| counts[RawDataExporter.threshold_index(item.cycle_time)] += 1 }
      plot = UnicodePlot.barplot(labels, counts, title: title, xlabel: 'Items Completed')
      render_to_string(plot, color: color)
    end

    def self.cfd_plot(work_items, title: 'Cumulative Flow Diagram', color: false, **_opts)
      cfd = Calculators::Cfd.calculate(work_items)
      return 'No CFD data to plot.' if cfd.empty?

      start = cfd.first[:date]
      coords = Calculators::Cfd.to_coordinates(cfd, start)
      max_y = coords[:arrived].max || 0
      max_x = coords[:dates].max || 0

      # Arrivals first for legend and top boundary
      plot = UnicodePlot.stairs(coords[:dates], coords[:arrived],
                                title: title, name: 'Arrivals',
                                xlabel: "Days since #{PredictabilityEngine.format_date(start)}", ylabel: 'Total Items',
                                color: :blue, xlim: [0, max_x], ylim: [0, max_y])
      # Departures next
      UnicodePlot.stairs!(plot, coords[:dates], coords[:departed], name: 'Departures', color: :green)
      render_to_string(plot, color: color)
    end

    def self.forecasted_cfd_plot(work_items, title: 'Forecasted Cumulative Flow Diagram', color: false,
                                 percentiles: PredictabilityEngine::DEFAULT_PERCENTILES, **_opts)
      data = Calculators::Cfd.forecast_series(work_items, percentiles: percentiles)
      return cfd_plot(work_items, title: title, color: color) unless data

      params = CfdRenderer.build_forecast_params(data)
      plot = UnicodePlot.stairs(params[:x_coords], params[:arrivals],
                                title: title, name: 'Arrivals', ylabel: 'Total Items',
                                xlabel: "Days since #{PredictabilityEngine.format_date(params[:start])}", color: :blue,
                                xlim: [0, params[:max_x]], ylim: [0, params[:total_items]])

      CfdRenderer.add_forecast_layers!(plot, data, params, percentiles)
      render_to_string(plot, color: color)
    end

    def self.render_to_string(plot, color: false)
      sio = StringIO.new
      plot.render(sio, color: color)
      sio.string
    end

    private_class_method :render_to_string
  end
end
