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

  HTML_BASE_STYLE = 'font-family: sans-serif; background: #f8f9fa;'

  HTML_STYLE_STANDARD = <<~CSS.freeze
    <style>
      body { #{HTML_BASE_STYLE} margin: 20px; background: white; }
      .section { margin-bottom: 50px; }
      .chart-container { width: 100%; height: 400px; margin-top: 10px; }
    </style>
  CSS

  HTML_STYLE_LANDSCAPE = <<~CSS.freeze
    <style>
      body { #{HTML_BASE_STYLE} margin: 0; padding: 15px; height: 100vh; box-sizing: border-box; display: flex; flex-direction: column; overflow: hidden; background: #f4f7f6; }
      header { display: flex; justify-content: space-between; align-items: baseline; padding: 0 10px 10px 10px; border-bottom: 2px solid #e9ecef; margin-bottom: 15px; }
      h1 { margin: 0; font-size: 1.5rem; color: #2c3e50; font-weight: 700; }
      .dashboard-container { display: grid; grid-template-columns: 260px 1fr 1fr; grid-template-rows: 1fr 1fr; gap: 15px; flex-grow: 1; min-height: 0; }
      .summary-panel { grid-row: span 2; background: white; padding: 20px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); overflow-y: auto; border: 1px solid #e9ecef; }
      .summary-panel h2 { font-size: 1.25rem; margin-top: 0; color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 8px; margin-bottom: 15px; }
      .summary-panel h3 { font-size: 1.1rem; color: #34495e; margin-top: 25px; border-bottom: 1px solid #eee; padding-bottom: 5px; }
      .chart-panel { background: white; padding: 15px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); display: flex; flex-direction: column; border: 1px solid #e9ecef; }
      .chart-panel h2 { margin: 0 0 10px 0; font-size: 1rem; color: #34495e; font-weight: 600; }
      .chart-container { flex-grow: 1; min-height: 0; width: 100%; display: flex; justify-content: center; align-items: center; }
      .chart-container > div { width: 100%; height: 100%; }
      ul { list-style: none; padding: 0; margin: 10px 0; }
      li { margin-bottom: 8px; font-size: 0.95rem; color: #505d6b; display: flex; justify-content: space-between; }
      li strong { color: #2c3e50; }
    </style>
  CSS

  HTML_BASE = <<~HTML.freeze
    <!DOCTYPE html>
    <html>
    #{HTML_HEADER}
    {{STYLE}}
    </head>
    <body>
      {{BODY}}
    </body>
    </html>
  HTML

  HTML_STANDARD_BODY = <<~HTML
    <h1>{{TITLE}}</h1>
    <div class="summary-container">{{SUMMARY_CONTENT}}</div>
    <div class="charts-container">{{CHART_CONTENT}}</div>
  HTML

  HTML_LANDSCAPE_BODY = <<~HTML
    <header>
      <h1>{{TITLE}}</h1>
      <div style="font-size: 0.8rem; color: #6c757d;">Generated: {{DATE}}</div>
    </header>
    <div class="dashboard-container">
      <div class="summary-panel">{{SUMMARY_CONTENT}}</div>
      {{CHART_PANELS}}
    </div>
  HTML

  private_constant :HTML_HEADER, :HTML_BASE, :HTML_STANDARD_BODY, :HTML_LANDSCAPE_BODY, :HTML_STYLE_STANDARD,
                   :HTML_STYLE_LANDSCAPE

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

    def self.aging_wip(items, color: false)
      TerminalVisualizer.aging_wip(items, color: color)
    end

    %i[cycle_time_scatter throughput_histogram cfd forecasted_cfd aging_wip dashboard].each do |m|
      define_singleton_method("vega_#{m}") { |items| VegaVisualizer.send(m, items) }
    end

    def self.to_full_html(content_or_chart, work_items = nil, title: 'Predictability Engine Dashboard',
                          layout: :standard)
      style = layout == :landscape ? HTML_STYLE_LANDSCAPE : HTML_STYLE_STANDARD
      body = layout == :landscape ? HTML_LANDSCAPE_BODY : HTML_STANDARD_BODY
      summary = work_items ? SummaryVisualizer.metrics_html(work_items) : ''

      html = HTML_BASE.gsub('{{STYLE}}', style).gsub('{{BODY}}', body)
      html.gsub!('{{TITLE}}', title)
      html.gsub!('{{DATE}}', Time.now.strftime('%Y-%m-%d %H:%M'))
      html.gsub!('{{SUMMARY_CONTENT}}', summary)

      content = prepare_html_content(content_or_chart, layout, html)
      html.gsub('{{CHART_CONTENT}}', content || '')
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
