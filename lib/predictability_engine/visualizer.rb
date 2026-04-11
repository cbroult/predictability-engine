# frozen_string_literal: true

require_relative 'terminal_visualizer'
require_relative 'vega_visualizer'
require_relative 'summary_visualizer'

module PredictabilityEngine
  HTML_HEADER = <<~HTML
    <head>
      <title>{{TITLE}}</title>
      <script src="https://cdn.jsdelivr.net/npm/vega@6"></script>
      <script src="https://cdn.jsdelivr.net/npm/vega-lite@5"></script>
      <script src="https://cdn.jsdelivr.net/npm/vega-embed@6"></script>
HTML

  HTML_TEMPLATE = <<~HTML
    <!DOCTYPE html>
    <html>
    #{HTML_HEADER}
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

  LANDSCAPE_TEMPLATE = <<~HTML.freeze
    <!DOCTYPE html>
    <html>
    #{HTML_HEADER}
      <style>
        body {#{' '}
          font-family: sans-serif; margin: 0; padding: 10px;#{' '}
          height: 100vh; display: flex; flex-direction: column; overflow: hidden;
          background: #f8f9fa;
        }
        header {#{' '}
          display: flex; justify-content: space-between; align-items: center;#{' '}
          padding-bottom: 5px; border-bottom: 1px solid #dee2e6; margin-bottom: 10px;
        }
        h1 { margin: 0; font-size: 1.2rem; color: #343a40; }
        .dashboard-container {#{' '}
          display: grid; grid-template-columns: 280px 1fr 1fr;#{' '}
          grid-template-rows: 1fr 1fr; gap: 10px; flex-grow: 1; min-height: 0;
        }
        .summary-panel {#{' '}
          grid-row: span 2; background: white; padding: 10px;#{' '}
          border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); overflow-y: auto;
        }
        .summary-panel h2 { font-size: 1.1rem; margin-top: 0; }
        .summary-panel h3 { font-size: 1rem; }
        .chart-panel {#{' '}
          background: white; padding: 10px; border-radius: 8px;#{' '}
          box-shadow: 0 1px 3px rgba(0,0,0,0.1); display: flex; flex-direction: column;
        }
        .chart-panel h2 { margin: 0 0 5px 0; font-size: 0.9rem; color: #495057; border-bottom: 1px solid #eee; }
        .chart-container { flex-grow: 1; min-height: 0; width: 100%; }
        ul { padding-left: 15px; margin: 5px 0; }
        li { margin-bottom: 3px; font-size: 0.85rem; }
      </style>
    </head>
    <body>
      <header>
        <h1>{{TITLE}}</h1>
        <div style="font-size: 0.8rem; color: #6c757d;">Generated: {{DATE}}</div>
      </header>
      <div class="dashboard-container">
        <div class="summary-panel">
          {{SUMMARY_CONTENT}}
        </div>
        {{CHART_PANELS}}
      </div>
    </body>
    </html>
  HTML

  private_constant :HTML_HEADER, :HTML_TEMPLATE, :LANDSCAPE_TEMPLATE

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

    def self.to_full_html(content_or_chart, work_items = nil, title: 'Predictability Engine Dashboard',
                          layout: :standard)
      template = layout == :landscape ? LANDSCAPE_TEMPLATE : HTML_TEMPLATE
      html = template.gsub('{{TITLE}}', title).gsub('{{DATE}}', Time.now.strftime('%Y-%m-%d %H:%M'))
      summary = work_items ? SummaryVisualizer.metrics_html(work_items) : ''

      content = prepare_html_content(content_or_chart, layout, html)
      html.gsub('{{SUMMARY_CONTENT}}', summary).gsub('{{CHART_CONTENT}}', content || '')
    end

    def self.prepare_html_content(content_or_chart, layout, html)
      if layout == :landscape && content_or_chart.is_a?(Array)
        panels = content_or_chart.map do |cfg|
          "<div class='chart-panel'><h2>#{cfg[:title]}</h2>" \
            "<div class='chart-container'>#{cfg[:chart].to_html}</div></div>"
        end.join("\n")
        html.gsub!('{{CHART_PANELS}}', panels)
        ''
      else
        content = content_or_chart.respond_to?(:to_html) ? content_or_chart.to_html : content_or_chart
        content.is_a?(Array) ? content.join("\n") : content
      end
    end

    private_class_method :prepare_html_content
  end
end
