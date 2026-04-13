# frozen_string_literal: true

require 'date'

module PredictabilityEngine
  module MermaidVisualizer
    def self.cfd_plot(items, **_opts)
      data = Calculators::Cfd.calculate(items).last(20)
      dates = data.map { |d| d[:date].to_s }
      format_mermaid_xy("Cumulative Flow Diagram (Last #{dates.size} days)", dates, 'Items',
                        [data.map { |d| d[:arrived] }, data.map { |d| d[:departed] }],
                        labels: %w[Arrivals Departures])
    end

    def self.forecasted_cfd_plot(items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES, **_opts)
      data = Calculators::Cfd.forecast_series(items, percentiles: percentiles)
      return cfd_plot(items) unless data

      series = [data[:arrivals]]
      labels = ['Arrivals']
      hist_size = data[:departed].size
      series << (data[:departed] + Array.new(data[:dates].size - hist_size, nil))
      labels << 'Departures'
      percentiles.each do |p|
        series << data[:forecasts][p]
        labels << "#{p}% Confidence"
        series << build_vertical_rule(data, p, hist_size)
        labels << "#{p}% Deadline"
      end

      format_mermaid_xy('Forecasted Cumulative Flow Diagram', data[:dates].map(&:to_s), 'Items',
                        series, labels: labels, thin: true)
    end

    def self.build_vertical_rule(data, percentile, hist_size)
      days = data[:summary][:"p#{percentile}"]
      index = hist_size - 1 + days
      res = Array.new(data[:dates].size, nil)
      res[index] = data[:summary][:total_items] if index < res.size
      res
    end

    def self.aging_wip(items, **_opts)
      data = Calculators::Aging.item_age_data(items)
      format_mermaid_xy('Aging Work In Progress', data.map { |d| d[:id] }, 'Age (days)',
                        [data.map { |d| d[:age] }], labels: ['Age'], type: 'bar')
    end

    def self.throughput_histogram(items, **_opts)
      counts = Calculators::Throughput.histogram_data(items)
      format_mermaid_xy('Throughput Histogram', counts.map { |c| c[0] }, 'Frequency',
                        [counts.map { |c| c[1] }], labels: ['Frequency'], type: 'bar')
    end

    def self.cycle_time_scatter(items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES, **_opts)
      completed = Calculators::CycleTime.completed_sorted(items)
      return '' if completed.empty?

      dates = completed.map { |i| i.end_date.to_s }.uniq.last(20)
      series = percentiles.map { |p| dates.map { |d| pct_at(completed, d, p) } }
      labels = percentiles.map { |p| "#{p}th Percentile" }

      format_mermaid_xy("Cycle Time Trend (Last #{dates.size} days)", dates, 'Cycle Time (days)',
                        series, labels: labels, thin: true)
    end

    def self.pct_at(items, date, pct)
      PredictabilityEngine.cycle_time_percentile(items.select { |i| i.end_date <= Date.parse(date) }, pct)
    end

    def self.format_mermaid_xy(title, x_axis, y_label, series, opts = {})
      ['xychart-beta', "    title \"#{title}\"", "    x-axis [\"#{format_x_axis(x_axis, opts).join('", "')}\"]",
       "    y-axis \"#{y_label}\"", *format_series(series, opts)].join("\n")
    end

    def self.format_x_axis(x_axis, opts)
      x_axis.each_with_index.map do |x, i|
        val = x.to_s.gsub('"', '')
        opts[:thin] && (i % 7 != 0) ? ' ' : val
      end
    end

    def self.format_series(series, opts)
      type = opts[:type] || 'line'
      labels = opts[:labels]
      series.each_with_index.map do |s, i|
        label = labels && labels[i] ? " \"#{labels[i]}\"" : ''
        "    #{type}#{label} [#{s.map { |v| v.nil? ? 'NaN' : v }.join(', ')}]"
      end
    end

    private_class_method :format_x_axis, :format_series
  end
end
