# frozen_string_literal: true

require 'date'

module PredictabilityEngine
  module MermaidVisualizer
    def self.cfd_plot(work_items)
      data = Calculators::Cfd.calculate(work_items).last(20)
      dates = data.map { |d| d[:date].to_s }
      format_mermaid_xy("Cumulative Flow Diagram (Last #{dates.size} days)", dates, 'Items',
                        [data.map { |d| d[:arrived] }, data.map { |d| d[:departed] }],
                        labels: %w[Arrivals Departures])
    end

    def self.forecasted_cfd_plot(work_items, percentiles: [50, 85, 95])
      cfd_data = Calculators::Cfd.calculate(work_items)
      return cfd_plot(work_items) if cfd_data.empty?

      forecast = Calculators::Cfd.forecast_points(work_items, percentiles: percentiles)
      return cfd_plot(work_items) unless forecast

      history = cfd_data.last(15)
      max_days = forecast[:max_days]

      dates, arrivals, base_departures = build_forecast_base(history, max_days)
      series = [arrivals]
      labels = ['Arrivals']

      percentiles.each do |p|
        series << build_forecast_series(history, base_departures, forecast[:"p#{p}"], max_days)
        labels << "#{p}% Confidence"
      end

      format_mermaid_xy('Forecasted Cumulative Flow Diagram', dates.map(&:to_s), 'Items',
                        series, labels: labels)
    end

    def self.aging_wip(work_items)
      data = Calculators::Aging.item_age_data(work_items)
      format_mermaid_xy('Aging Work In Progress', data.map { |d| d[:id] }, 'Age (days)',
                        [data.map { |d| d[:age] }], labels: ['Age'], type: 'bar')
    end

    def self.throughput_histogram(work_items)
      counts = Calculators::Throughput.histogram_data(work_items)
      format_mermaid_xy('Throughput Histogram', counts.map { |c| c[0] }, 'Frequency',
                        [counts.map { |c| c[1] }], labels: ['Frequency'], type: 'bar')
    end

    def self.cycle_time_scatter(work_items)
      completed = Calculators::CycleTime.completed_sorted(work_items)
      return '' if completed.empty?

      dates = completed.map { |i| i.end_date.to_s }.uniq.last(20)
      pcts = [50, 85, 95]
      series = pcts.map { |p| dates.map { |d| pct_at(completed, d, p) } }
      labels = pcts.map { |p| "#{p}th Percentile" }

      format_mermaid_xy("Cycle Time Trend (Last #{dates.size} days)", dates, 'Cycle Time (days)',
                        series, labels: labels)
    end

    def self.pct_at(items, date, pct)
      PredictabilityEngine.cycle_time_percentile(items.select { |i| i.end_date <= Date.parse(date) }, pct)
    end

    def self.build_forecast_base(history, max_days)
      dates = history.map { |d| d[:date] }
      arrivals = history.map { |d| d[:arrived] }
      departures = history.map { |d| d[:departed] }
      (1..max_days).each do |i|
        dates << (history.last[:date] + i)
        arrivals << history.last[:arrived]
      end
      [dates, arrivals, departures]
    end

    def self.build_forecast_series(history, departures, p_pts, max_days)
      days_to_complete = (p_pts.last[:date] - history.last[:date]).to_i
      backlog = p_pts.last[:count] - history.last[:departed]
      res = departures.dup
      (1..max_days).each do |i|
        res << if i <= days_to_complete
                 (history.last[:departed] + (i * (backlog.to_f / days_to_complete))).round
               else
                 p_pts.last[:count]
               end
      end
      res
    end

    def self.format_mermaid_xy(title, x_axis, y_label, series, opts = {})
      type = opts[:type] || 'line'
      labels = opts[:labels]
      lines = series.each_with_index.map do |s, i|
        label = labels && labels[i] ? " \"#{labels[i]}\"" : ''
        "    #{type}#{label} [#{s.join(', ')}]"
      end
      x_vals = x_axis.map { |x| x.to_s.gsub('"', '') }
      ['xychart-beta', "    title \"#{title}\"", "    x-axis [#{x_vals.join(', ')}]",
       "    y-axis \"#{y_label}\"", *lines].join("\n")
    end
  end
end
