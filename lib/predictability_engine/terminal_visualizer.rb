# frozen_string_literal: true

require 'unicode_plot'
require 'stringio'

module PredictabilityEngine
  module TerminalVisualizer
    def self.aging_wip(items, color: false, pcts: DEFAULT_PERCENTILES, **)
      data = Calculators::Aging.item_age_data(items)
      return 'No items currently in progress.' if data.empty?

      PredictabilityEngine.mapped_percentiles(items, pcts)
      plot = UnicodePlot.barplot(data.map { |d| d[:id].to_s }, data.map { |d| d[:age] },
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

      params = build_forecast_params(data)
      plot = UnicodePlot.stairs(params[:x_coords], params[:arrivals],
                                title: title, name: 'Arrivals', ylabel: 'Total Items',
                                xlabel: "Days since #{PredictabilityEngine.format_date(params[:start])}", color: :blue,
                                xlim: [0, params[:max_x]], ylim: [0, params[:total_items]])

      add_forecast_layers!(plot, data, params, percentiles)
      render_to_string(plot, color: color)
    end

    def self.build_forecast_params(data)
      start = data[:dates].first
      {
        start: start,
        x_coords: data[:dates].map { |d| (d - start).to_i },
        hist_size: data[:departed].size,
        total_items: data[:summary][:total_items],
        max_x: data[:dates].map { |d| (d - start).to_i }.max || 0,
        arrivals: data[:arrivals]
      }
    end

    def self.add_forecast_layers!(plot, data, params, percentiles)
      # Departures next
      add_historical_departures!(plot, data, params)

      # Forecast confidence paths
      # Use distinct colors for forecast paths
      f_colors = { 50 => :yellow, 75 => :red, 85 => :magenta, 95 => :cyan, 98 => :white }
      sorted_pcts = percentiles.sort
      sorted_pcts.reverse.each do |p|
        add_confidence_layer!(plot, data, params, p, sorted_pcts: sorted_pcts, color: f_colors[p] || :white)
      end
    end

    def self.add_historical_departures!(plot, data, params)
      UnicodePlot.stairs!(plot, params[:x_coords].take(params[:hist_size]), data[:departed],
                          name: 'Departures', color: :green)
    end

    def self.add_confidence_layer!(plot, data, params, percentile, **opts)
      sorted_pcts = opts[:sorted_pcts]
      color = opts[:color]
      # Slice to only show forecast from the last historical point onwards
      f_x = params[:x_coords].drop(params[:hist_size] - 1)
      f_y = data[:forecasts][percentile].drop(params[:hist_size] - 1)

      UnicodePlot.lineplot!(plot, f_x, f_y, name: "#{percentile}% Confidence", color: color)

      # Shift to the next percentile's date for rule alignment, except for the last one
      idx = sorted_pcts.index(percentile)
      target_p = idx < sorted_pcts.size - 1 ? sorted_pcts[idx + 1] : percentile
      deadline_idx = params[:hist_size] - 1 + data[:summary][:"p#{target_p}"]
      deadline_x = params[:x_coords][deadline_idx]
      # Use the forecast value at the deadline to hit the corner of the surface
      forecast_at_deadline = data[:forecasts][percentile][deadline_idx]
      # Use normal color for vertical lines (neutral); omitted from legend
      UnicodePlot.lineplot!(plot, [deadline_x, deadline_x], [0, forecast_at_deadline], color: :normal)
    end

    def self.render_to_string(plot, color: false)
      sio = StringIO.new
      plot.render(sio, color: color)
      sio.string
    end

    private_class_method :render_to_string, :build_forecast_params, :add_forecast_layers!
  end
end
