# frozen_string_literal: true

require 'date'

module PredictabilityEngine
  module MermaidVisualizer
    def self.cfd_plot(work_items)
      data = Calculators::Cfd.calculate(work_items)
      data = data.last(20) # Limit to 20 days for readability
      dates = data.map { |d| d[:date].to_s }
      arrivals = data.map { |d| d[:arrived] }
      departures = data.map { |d| d[:departed] }

      [
        'xychart-beta',
        "    title \"Cumulative Flow Diagram (Last #{dates.size} days)\"",
        "    x-axis [#{dates.join(', ')}]",
        '    y-axis "Items"',
        "    line [#{arrivals.join(', ')}]",
        "    line [#{departures.join(', ')}]"
      ].join("\n")
    end

    def self.forecasted_cfd_plot(work_items)
      cfd_data = Calculators::Cfd.calculate(work_items)
      historical_tp = Calculators::Throughput.daily(work_items).values
      backlog = work_items.reject(&:completed?).size
      return cfd_plot(work_items) if cfd_data.empty? || backlog.zero? || historical_tp.empty?

      p50 = Simulators::MonteCarlo.when_will_it_be_done(backlog, historical_tp).then do |res|
        Simulators::MonteCarlo.percentile(res, 50)
      end

      history = cfd_data.last(15)
      dates, arrivals, departures = build_forecast_arrays(history, p50, backlog)

      format_mermaid_xy('Forecasted Cumulative Flow Diagram', dates.map(&:to_s), 'Items',
                        [arrivals, departures], type: 'line')
    end

    def self.build_forecast_arrays(history, p50, backlog)
      dates = history.map { |d| d[:date] }
      arrivals = history.map { |d| d[:arrived] }
      departures = history.map { |d| d[:departed] }
      last_historical = history.last

      (1..p50).each do |i|
        dates << (last_historical[:date] + i)
        arrivals << last_historical[:arrived]
        departures << (last_historical[:departed] + (i * (backlog.to_f / p50)).round)
      end
      [dates, arrivals, departures]
    end

    def self.format_mermaid_xy(title, x_axis, y_label, series, type: 'line')
      lines = series.map { |s| "    #{type} [#{s.join(', ')}]" }
      [
        'xychart-beta',
        "    title \"#{title}\"",
        "    x-axis [#{x_axis.join(', ')}]",
        "    y-axis \"#{y_label}\"",
        *lines
      ].join("\n")
    end

    private_class_method :build_forecast_arrays, :format_mermaid_xy

    def self.throughput_histogram(work_items)
      daily = Calculators::Throughput.daily(work_items)
      counts = daily.values.tally.sort

      labels = counts.map { |c| c[0] }
      values = counts.map { |c| c[1] }

      [
        'xychart-beta',
        '    title "Throughput Histogram"',
        "    x-axis [#{labels.join(', ')}]",
        '    y-axis "Frequency"',
        "    bar [#{values.join(', ')}]"
      ].join("\n")
    end
  end
end
