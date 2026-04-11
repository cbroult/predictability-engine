# frozen_string_literal: true

require 'date'

module PredictabilityEngine
  module MermaidVisualizer
    def self.cfd_plot(work_items)
      data = Calculators::Cfd.calculate(work_items).last(20)
      dates = data.map { |d| d[:date].to_s }
      format_mermaid_xy("Cumulative Flow Diagram (Last #{dates.size} days)", dates, 'Items',
                        [data.map { |d| d[:arrived] }, data.map { |d| d[:departed] }])
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
                        [arrivals, departures])
    end

    def self.aging_wip(work_items)
      data = Calculators::Aging.item_age_data(work_items)
      format_mermaid_xy('Aging Work In Progress', data.map { |d| d[:id] }, 'Age (days)',
                        [data.map { |d| d[:age] }], type: 'bar')
    end

    def self.throughput_histogram(work_items)
      counts = Calculators::Throughput.histogram_data(work_items)
      format_mermaid_xy('Throughput Histogram', counts.map { |c| c[0] }, 'Frequency',
                        [counts.map { |c| c[1] }], type: 'bar')
    end

    def self.cycle_time_scatter(work_items)
      completed = Calculators::CycleTime.completed_sorted(work_items)
      return '' if completed.empty?

      dates = completed.map { |i| i.end_date.to_s }.uniq.last(20)
      p50s = dates.map { |d| pct_at(completed, d, 50) }
      p85s = dates.map { |d| pct_at(completed, d, 85) }

      format_mermaid_xy("Cycle Time Trend (Last #{dates.size} days)", dates, 'Cycle Time (days)', [p50s, p85s])
    end

    def self.pct_at(items, date, pct)
      PredictabilityEngine.cycle_time_percentile(items.select { |i| i.end_date <= Date.parse(date) }, pct)
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
      ['xychart-beta', "    title \"#{title}\"", "    x-axis [#{x_axis.join(', ')}]",
       "    y-axis \"#{y_label}\"", *lines].join("\n")
    end
  end
end
