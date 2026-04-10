# frozen_string_literal: true

require_relative 'terminal_visualizer'
require_relative 'vega_visualizer'
require_relative 'summary_visualizer'

module PredictabilityEngine
  HTML_TEMPLATE = <<~HTML
    <!DOCTYPE html>
    <html>
    <head>
      <title>{{TITLE}}</title>
      <script src="https://cdn.jsdelivr.net/npm/vega@6"></script>
      <script src="https://cdn.jsdelivr.net/npm/vega-lite@5"></script>
      <script src="https://cdn.jsdelivr.net/npm/vega-embed@6"></script>
      <style>
        body { font-family: sans-serif; margin: 20px; }
        .section { margin-bottom: 50px; }
        .chart-container { width: 100%; height: 400px; margin-top: 10px; }
      </style>
    </head>
    <body>
      <h1>{{TITLE}}</h1>
      <div class="summary-container">
        {{SUMMARY_CONTENT}}
      </div>
      <div class="charts-container">
        {{CHART_CONTENT}}
      </div>
    </body>
    </html>
  HTML
  private_constant :HTML_TEMPLATE

  class Visualizer
    def self.cycle_time_scatter(items, color: false)
      TerminalVisualizer.cycle_time_scatter(items, color: color)
    end

    def self.throughput_histogram(items, color: false)
      TerminalVisualizer.throughput_histogram(items, color: color)
    end

    def self.cfd_plot(items, color: false)
      TerminalVisualizer.cfd_plot(items, color: color)
    end

    def self.forecasted_cfd_plot(items, color: false)
      TerminalVisualizer.forecasted_cfd_plot(items, color: color)
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

    def self.to_full_html(content_or_chart, work_items = nil, title: 'Predictability Engine Dashboard')
      html = HTML_TEMPLATE.gsub('{{TITLE}}', title)
      summary = work_items ? SummaryVisualizer.metrics_html(work_items) : ''
      content = content_or_chart.respond_to?(:to_html) ? content_or_chart.to_html : content_or_chart
      html.gsub('{{SUMMARY_CONTENT}}', summary).gsub('{{CHART_CONTENT}}', content)
    end
  end
end
