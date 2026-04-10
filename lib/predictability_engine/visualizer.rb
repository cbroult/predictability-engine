# frozen_string_literal: true

require 'unicode_plot'
require 'vega'

module PredictabilityEngine
  HTML_TEMPLATE = <<~HTML
    <!DOCTYPE html>
    <html>
    <head>
      <title>Predictability Engine Dashboard</title>
      <script src="https://cdn.jsdelivr.net/npm/vega@6"></script>
      <script src="https://cdn.jsdelivr.net/npm/vega-lite@5"></script>
      <script src="https://cdn.jsdelivr.net/npm/vega-embed@6"></script>
      <style>
        body { font-family: sans-serif; margin: 20px; }
        .chart-container { margin-bottom: 50px; }
      </style>
    </head>
    <body>
      <h1>Predictability Metrics Dashboard</h1>
      <div class="summary-container">
        {{SUMMARY_CONTENT}}
      </div>
      <div class="chart-container">
        {{CHART_CONTENT}}
      </div>
    </body>
    </html>
  HTML
  private_constant :HTML_TEMPLATE

  class Visualizer
    def self.cycle_time_scatter(work_items, title: 'Cycle Time Scatter Plot')
      completed = work_items.select(&:completed?).sort_by(&:end_date)
      return 'No completed items to plot.' if completed.empty?

      x = completed.map { |item| (item.end_date - completed.first.end_date).to_i }
      y = completed.map(&:cycle_time)

      xlabel = "Days since #{completed.first.end_date}"
      plot = UnicodePlot.scatterplot(x, y, title: title, xlabel: xlabel, ylabel: 'Cycle Time (days)')
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

    def self.render_cfd_unicode_plot(cfd_data, title)
      dates = cfd_data.map { |d| (d[:date] - cfd_data.first[:date]).to_i }
      plot = UnicodePlot.lineplot(dates, cfd_data.map { |d| d[:arrived] },
                                  title: title, name: 'Arrivals', ylabel: 'Total Items',
                                  xlabel: "Days since #{cfd_data.first[:date]}")
      UnicodePlot.lineplot!(plot, dates, cfd_data.map { |d| d[:departed] }, name: 'Departures')
      plot.render
    end

    # Vega (HTML) versions
    def self.vega_cycle_time_scatter(work_items)
      data = work_items.select(&:completed?).map do |item|
        { date: item.end_date.to_s, cycle_time: item.cycle_time, id: item.id }
      end

      Vega.lite
          .data(data)
          .title('Cycle Time Scatter Plot')
          .mark(type: 'point', tooltip: true)
          .encoding(
            x: { field: 'date', type: 'temporal', title: 'Completion Date' },
            y: { field: 'cycle_time', type: 'quantitative', title: 'Cycle Time (days)' },
            color: { value: '#4c78a8' }
          )
          .width(600)
          .height(400)
    end

    def self.vega_throughput_histogram(work_items)
      daily_tp = Calculators::Throughput.daily(work_items).values
      data = daily_tp.map { |v| { throughput: v } }

      Vega.lite
          .data(data)
          .title('Throughput Histogram')
          .mark(type: 'bar', tooltip: true)
          .encoding(
            x: { field: 'throughput', type: 'quantitative', bin: true, title: 'Items per Day' },
            y: { aggregate: 'count', type: 'quantitative', title: 'Frequency' }
          )
          .width(600)
          .height(400)
    end

    def self.vega_cfd(work_items)
      cfd_data = Calculators::Cfd.calculate(work_items)
      data = []
      cfd_data.each do |d|
        data << { date: d[:date].to_s, count: d[:arrived], type: 'Arrivals' }
        data << { date: d[:date].to_s, count: d[:departed], type: 'Departures' }
      end

      Vega.lite
          .data(data)
          .title('Cumulative Flow Diagram')
          .mark(type: 'area', line: true, tooltip: true)
          .encoding(
            x: { field: 'date', type: 'temporal', title: 'Date' },
            y: { field: 'count', type: 'quantitative', title: 'Total Items', stack: nil },
            color: { field: 'type', type: 'nominal', scale: { range: ['#4c78a8', '#f58518'] } }
          )
          .width(600)
          .height(400)
    end

    def self.vega_dashboard(work_items)
      scatter = vega_cycle_time_scatter(work_items).spec.except('$schema')
      throughput = vega_throughput_histogram(work_items).spec.except('$schema')
      cfd = vega_cfd(work_items).spec.except('$schema')

      Vega.lite.vconcat([scatter, throughput, cfd])
    end

    def self.to_full_html(chart, work_items = nil)
      html = HTML_TEMPLATE.gsub('{{CHART_CONTENT}}', chart.to_html)
      summary = work_items ? summary_metrics_html(work_items) : ''
      html.gsub('{{SUMMARY_CONTENT}}', summary)
    end

    def self.summary_metrics_html(work_items)
      completed = work_items.select(&:completed?)
      tp_avg = Calculators::Throughput.average(work_items)
      p50 = Calculators::CycleTime.percentile(work_items, 50)
      p85 = Calculators::CycleTime.percentile(work_items, 85)
      p95 = Calculators::CycleTime.percentile(work_items, 95)

      <<~HTML
        <h2>Flow Metrics Summary</h2>
        <ul>
          <li><strong>Total Items:</strong> #{work_items.size}</li>
          <li><strong>Completed Items:</strong> #{completed.size}</li>
          <li><strong>Average Throughput:</strong> #{tp_avg.round(2)} items/day</li>
          <li><strong>Cycle Time (p50):</strong> #{p50} days</li>
          <li><strong>Cycle Time (p85):</strong> #{p85} days</li>
          <li><strong>Cycle Time (p95):</strong> #{p95} days</li>
        </ul>
      HTML
    end

    def self.summary_metrics_terminal(work_items)
      completed = work_items.select(&:completed?)
      tp_avg = Calculators::Throughput.average(work_items)
      p50 = Calculators::CycleTime.percentile(work_items, 50)
      p85 = Calculators::CycleTime.percentile(work_items, 85)
      p95 = Calculators::CycleTime.percentile(work_items, 95)

      [
        'Flow Metrics Summary',
        '--------------------',
        "Total Items: #{work_items.size}",
        "Completed Items: #{completed.size}",
        "Average Throughput: #{tp_avg.round(2)} items/day",
        '',
        'Cycle Time Percentiles:',
        "  50th Percentile: #{p50} days",
        "  85th Percentile: #{p85} days",
        "  95th Percentile: #{p95} days",
        ''
      ].join("\n")
    end
  end
end
