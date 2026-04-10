# frozen_string_literal: true

require_relative 'terminal_visualizer'
require_relative 'vega_visualizer'
require_relative 'summary_visualizer'

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
    def self.cycle_time_scatter(items)
      TerminalVisualizer.cycle_time_scatter(items)
    end

    def self.throughput_histogram(items)
      TerminalVisualizer.throughput_histogram(items)
    end

    def self.cfd_plot(items)
      TerminalVisualizer.cfd_plot(items)
    end

    def self.forecasted_cfd_plot(items)
      TerminalVisualizer.forecasted_cfd_plot(items)
    end

    def self.vega_cycle_time_scatter(items)
      VegaVisualizer.cycle_time_scatter(items)
    end

    def self.vega_throughput_histogram(items)
      VegaVisualizer.throughput_histogram(items)
    end

    def self.vega_cfd(items)
      VegaVisualizer.cfd(items)
    end

    def self.vega_forecasted_cfd(items)
      VegaVisualizer.forecasted_cfd(items)
    end

    def self.vega_dashboard(items)
      VegaVisualizer.dashboard(items)
    end

    def self.to_full_html(chart, work_items = nil)
      html = HTML_TEMPLATE.gsub('{{CHART_CONTENT}}', chart.to_html)
      summary = work_items ? SummaryVisualizer.metrics_html(work_items) : ''
      html.gsub('{{SUMMARY_CONTENT}}', summary)
    end
  end
end
