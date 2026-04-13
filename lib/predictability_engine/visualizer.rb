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

  HTML_STYLE_LANDSCAPE = <<~CSS.freeze
    <style>
      body { #{HTML_BASE_STYLE} margin: 0; padding: 15px; box-sizing: border-box; display: flex; flex-direction: column; background: #f4f7f6; }
      header { display: flex; justify-content: space-between; align-items: baseline; padding: 0 10px 10px 10px; border-bottom: 2px solid #e9ecef; margin-bottom: 15px; }
      h1 { margin: 0; font-size: 1.5rem; color: #2c3e50; font-weight: 700; }
      .nav-links { display: flex; gap: 10px; list-style: none; margin: 0; padding: 0; align-items: center; }
      .nav-links li { margin: 0; display: block; }
      .nav-links a { text-decoration: none; color: #3498db; font-size: 0.9rem; padding: 5px 12px; border-radius: 20px; border: 1.5px solid #3498db; font-weight: 600; transition: all 0.2s; }
      .nav-links a:hover { background: #3498db; color: white; }
      .nav-links a.active { background: #2c3e50; color: white; border-color: #2c3e50; cursor: default; }
      .dashboard-container { display: grid; grid-template-columns: 260px 1fr 1fr; grid-template-rows: 1fr 1fr; gap: 15px; flex-grow: 1; min-height: 0; min-width: 1050px; }
      .summary-panel { grid-row: span 2; background: white; padding: 20px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); overflow-y: auto; border: 1px solid #e9ecef; }
      .summary-panel h2 { font-size: 1.25rem; margin-top: 0; color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 8px; margin-bottom: 15px; }
      .summary-panel h3 { font-size: 1.1rem; color: #34495e; margin-top: 25px; border-bottom: 1px solid #eee; padding-bottom: 5px; }
      .chart-panel { background: white; padding: 15px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); display: flex; flex-direction: column; border: 1px solid #e9ecef; min-height: 280px; }
      .chart-panel h2 { margin: 0 0 10px 0; font-size: 1rem; color: #34495e; font-weight: 600; }
      .chart-container { flex-grow: 1; min-height: 0; width: 100%; display: flex; justify-content: center; align-items: center; }
      .chart-container > div { width: 100% !important; height: 100% !important; }
      ul { list-style: none; padding: 0; margin: 10px 0; }
      li { margin-bottom: 8px; font-size: 0.95rem; color: #505d6b; display: flex; justify-content: space-between; }
      li strong { color: #2c3e50; }

      @media screen {
        body { height: 100vh; overflow: auto; }
      }

      @media print {
        body { height: auto; overflow: visible; padding: 5px; background: white; }
        .dashboard-container { grid-template-columns: 220px 1fr 1fr; gap: 10px; }
        .chart-panel, .summary-panel { box-shadow: none; border: 1px solid #eee; padding: 10px; }
        header { margin-bottom: 10px; padding-bottom: 5px; }
        h1 { font-size: 1.2rem; }
      }
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

  HTML_LANDSCAPE_BODY = <<~HTML
    <header>
      <h1>{{TITLE}}</h1>
      <nav>{{NAV_BAR}}</nav>
      <div style="font-size: 0.8rem; color: #6c757d;">Generated: {{DATE}}</div>
    </header>
    <div class="dashboard-container">
      <div class="summary-panel">{{SUMMARY_CONTENT}}</div>
      {{CHART_PANELS}}
    </div>
  HTML

  private_constant :HTML_HEADER, :HTML_BASE, :HTML_LANDSCAPE_BODY,
                   :HTML_STYLE_LANDSCAPE

  class Visualizer
    def self.cycle_time_scatter(items, color: false, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      TerminalVisualizer.cycle_time_scatter(items, color: color, percentiles: percentiles)
    end

    def self.throughput_histogram(items, color: false)
      TerminalVisualizer.throughput_histogram(items, color: color)
    end

    def self.cfd_plot(items, color: false)
      TerminalVisualizer.cfd_plot(items, color: color)
    end

    def self.forecasted_cfd_plot(items, color: false, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      TerminalVisualizer.forecasted_cfd_plot(items, color: color, percentiles: percentiles)
    end

    def self.aging_wip(items, color: false, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      TerminalVisualizer.aging_wip(items, color: color, percentiles: percentiles)
    end

    %i[cycle_time_scatter throughput_histogram cfd forecasted_cfd aging_wip dashboard].each do |m|
      define_singleton_method("vega_#{m}") { |items| VegaVisualizer.send(m, items) }
    end

    def self.to_full_html(content_or_chart, work_items = nil, **opts)
      title = opts.fetch(:title, 'Predictability Engine Dashboard')
      percentiles = opts.fetch(:percentiles, PredictabilityEngine::DEFAULT_PERCENTILES)
      sub_reports = opts.fetch(:sub_reports, nil)

      style = HTML_STYLE_LANDSCAPE
      body = HTML_LANDSCAPE_BODY
      summary = work_items ? SummaryVisualizer.metrics_html(work_items, percentiles: percentiles) : ''

      nav_bar = build_nav_bar(sub_reports)

      html = HTML_BASE.gsub('{{STYLE}}', style).gsub('{{BODY}}', body)
      html.gsub!('{{TITLE}}', title)
      html.gsub!('{{DATE}}', Time.now.strftime('%Y-%m-%d %H:%M'))
      html.gsub!('{{SUMMARY_CONTENT}}', summary)
      html.gsub!('{{NAV_BAR}}', nav_bar)

      content = prepare_html_content(content_or_chart, :landscape, html)
      # If it was a single chart, it might still have {{CHART_PANELS}} placeholder
      if html.include?('{{CHART_PANELS}}')
        panel = "<div class='chart-panel' style='grid-column: span 2; grid-row: span 2;'>" \
                "<div class='chart-container'>#{content}</div></div>"
        html.gsub!('{{CHART_PANELS}}', panel)
      end
      html
    end

    def self.build_nav_bar(sub_reports)
      return '' unless sub_reports&.any?

      links = sub_reports.map do |r|
        "<li><a href='#{r[:url]}' class='#{'active' if r[:active]}'>#{r[:label]}</a></li>"
      end.join
      "<ul class='nav-links'><li><strong>View:</strong></li>#{links}</ul>"
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
