# frozen_string_literal: true

require_relative 'terminal_visualizer'
require_relative 'vega_visualizer'
require_relative 'summary_visualizer'
require_relative 'html_style'
require_relative 'html_templates'

module PredictabilityEngine
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
      define_singleton_method("vega_#{m}") { |items, **opts| VegaVisualizer.send(m, items, **opts) }
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
      html.gsub!('{{DATE}}', PredictabilityEngine.format_datetime(Time.now))
      html.gsub!('{{SUMMARY_CONTENT}}', summary)
      html.gsub!('{{NAV_BAR}}', nav_bar)

      content = prepare_html_content(content_or_chart, :landscape, html)
      # If it was a single chart, it might still have {{CHART_PANELS}} placeholder
      if html.include?('{{CHART_PANELS}}')
        panel = "<div class='chart-panel' style='grid-column: span 2; grid-row: span 2;'>" \
                "<div class='panel-header'>" \
                "<button class='chart-expand' onclick='toggleFullscreen(this)' title='Expand'></button></div>" \
                "<div class='chart-container'>#{content}</div></div>"
        html.gsub!('{{CHART_PANELS}}', panel)
      end
      html
    end

    def self.build_nav_bar(sub_reports)
      return '' unless sub_reports&.any?

      view_items, dl_items = sub_reports.partition { |r| !r[:download] }
      html = view_nav_section(view_items) + export_nav_section(dl_items, view_items.any?)
      "<ul class='nav-links'>#{html}</ul>"
    end

    def self.view_nav_section(view_items)
      return '' unless view_items.any?

      "<li><strong>View:</strong></li>#{view_items.map { |r| nav_item(r) }.join}"
    end

    def self.export_nav_section(dl_items, has_view)
      return '' unless dl_items.any?

      sep = has_view ? "<li class='nav-sep' aria-hidden='true'>|</li>" : ''
      "#{sep}<li><strong>Export:</strong></li>#{dl_items.map { |r| nav_item(r) }.join}"
    end

    def self.nav_item(entry)
      return "<li class='nav-sep' aria-hidden='true'>|</li>" if entry[:separator]

      dl = entry[:download] ? ' download' : ''
      "<li><a href='#{entry[:url]}' class='#{'active' if entry[:active]}'#{dl}>#{entry[:label]}</a></li>"
    end

    def self.prepare_html_content(content_or_chart, layout, html)
      if layout == :landscape && content_or_chart.is_a?(Array)
        panels = content_or_chart.map do |cfg|
          "<div class='chart-panel'>" \
            "<div class='panel-header'><h2>#{cfg[:title]}</h2>" \
            "<button class='chart-expand' onclick='toggleFullscreen(this)' title='Expand'></button></div>" \
            "<div class='chart-container'>#{cfg[:chart].to_html}</div></div>"
        end.join("\n")
        html.gsub!('{{CHART_PANELS}}', panels)
        ''
      else
        content = content_or_chart.respond_to?(:to_html) ? content_or_chart.to_html : content_or_chart
        content.is_a?(Array) ? content.join("\n") : content
      end
    end

    private_class_method :prepare_html_content, :view_nav_section, :export_nav_section
  end
end
