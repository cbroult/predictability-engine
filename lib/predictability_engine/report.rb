# frozen_string_literal: true

require 'fileutils'
require_relative 'report/constants'
require_relative 'report/image_generator'
require_relative 'report/text_renderer'

module PredictabilityEngine
  class Report
    include Constants

    attr_reader :items, :title, :percentiles, :images_path

    def initialize(items, title: 'Predictability Report', percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      @items = items
      @title = title
      @percentiles = percentiles
      @images_path = nil
    end

    def self.generate_all(items) = new(items, title: 'Full Predictability Dashboard')

    def render(format, layout: nil, color: false)
      config = find_format_config(format)&.last
      method_name = "render_#{find_format_config(format)&.first || format.to_sym}"
      raise ArgumentError, "Unsupported format: #{format}" unless respond_to?(method_name, true)

      opts = { layout: effective_layout(layout, config), color: color }
      opts[:format] = config[:format] if config&.key?(:format)
      opts[:landscape] = config[:landscape] if config&.key?(:landscape)
      send(method_name, **opts)
    end

    def generate_chart_images(base_dir)
      @images_path = ImageGenerator.generate(self, base_dir)
    rescue StandardError => e
      warn "Chart image generation failed: #{e.message}. Falling back to Mermaid/ASCII."
      @images_path = nil
    end

    def render_html(layout: :standard, **_opts)
      charts = CHART_CONFIG.map do |id, cfg|
        chart = VegaVisualizer.send(cfg[:vega] || id, @items,
                                    title: (layout.to_sym == :landscape ? nil : cfg[:title]),
                                    percentiles: @percentiles)
        if layout.to_sym == :landscape
          { title: cfg[:title], chart: chart }
        else
          "<div class='section'><h2>#{cfg[:title]}</h2>#{chart.to_html}</div>"
        end
      end
      Visualizer.to_full_html(charts, @items, title: @title, layout: layout, percentiles: @percentiles)
    end

    def playwright_bin
      root = File.expand_path('../..', __dir__)
      ENV['PLAYWRIGHT_BROWSERS_PATH'] ||= File.expand_path('~/.cache/ms-playwright')
      File.exist?("#{root}/node_modules/.bin/playwright") ? "#{root}/node_modules/.bin/playwright" : 'npx playwright'
    end

    def pdf_viewport_size(format, landscape)
      sizes = { 'A4' => [794, 1123], 'A3' => [1123, 1587] }
      w, h = sizes[format] || [794, 1123]
      landscape ? [h, w] : [w, h]
    end

    def render_image_link(chart_id, fmt)
      rel_path = "images/#{chart_id}.png"
      fmt == :confluence ? "!#{rel_path}!" : "![](#{rel_path})"
    end

    private

    def find_format_config(format)
      fmt = format.to_sym
      FORMAT_CONFIG.find { |k, v| k == fmt || v[:aliases]&.include?(fmt) }
    end

    def effective_layout(layout, config) = (layout || config&.dig(:layout) || :standard).to_sym

    %i[terminal markdown confluence].each do |f|
      define_method("render_#{f}") { |**o| TextRenderer.render(self, f, **o) }
    end

    def render_landscape(layout: :landscape, **) = render_html(layout: layout, **)
    def render_a3_landscape(**) = render_pdf(**)

    def render_pdf(layout: :landscape, high_fidelity: true, format: 'A4', landscape: true, **_opts)
      high_fidelity ? render_pdf_playwright(layout: layout, format: format, landscape: landscape) : render_pdf_prawn
    rescue StandardError => e
      warn "High-fidelity PDF generation failed: #{e.message}. Falling back to Prawn."
      render_pdf_prawn
    end

    def render_pdf_playwright(layout: :landscape, format: 'A4', landscape: true)
      require 'playwright'
      temp_html = "tmp/report_#{object_id}.html"
      FileUtils.mkdir_p('tmp')
      File.write(temp_html, render_html(layout: layout))
      pdf_data = capture_pdf(temp_html, format, landscape)
      pdf_data
    ensure
      FileUtils.rm_f(temp_html)
    end

    def capture_pdf(html_path, format, landscape)
      pdf_data = nil
      Playwright.create(playwright_cli_executable_path: playwright_bin) do |p|
        p.chromium.launch do |browser|
          w, h = pdf_viewport_size(format, landscape)
          page = browser.new_page(viewport: { width: w, height: h })
          page.goto("file://#{File.expand_path(html_path)}")
          sleep 2
          pdf_data = page.pdf(format: format, landscape: landscape, printBackground: true,
                              margin: { top: '0', right: '0', bottom: '0', left: '0' })
        end
      end
      pdf_data
    end

    def render_pdf_prawn(**_opts)
      require 'prawn'
      Prawn::Document.new do |pdf|
        Report.send(:setup_pdf_font_on_doc, pdf)
        pdf.text @title, size: 24, style: :bold
        pdf.move_down 20
        pdf.text SummaryVisualizer.metrics_terminal(@items, color: false, percentiles: @percentiles)
        CHART_CONFIG.each_key do |id|
          pdf.start_new_page
          pdf.text CHART_CONFIG[id][:title], size: 18, style: :bold
          pdf.move_down 20
          PdfVisualizer.draw_chart(pdf, id, @items, percentiles: @percentiles)
          pdf.move_down 20
          pdf.text 'ASCII Representation:', size: 10, style: :bold
          pdf.text TerminalVisualizer.send(id, @items, color: false, percentiles: @percentiles), size: 7
        end
      end.render
    end

    def self.setup_pdf_font_on_doc(pdf)
      mono = find_font(Constants::FONT_PATHS)
      bold = find_font(Constants::FONT_BOLD_PATHS)
      return unless mono && bold

      pdf.font_families.update('CustomMono' => { normal: mono, bold: bold })
      pdf.font 'CustomMono'
    end

    def self.find_font(paths) = paths.find { |p| File.exist?(p) }

    private_class_method :setup_pdf_font_on_doc, :find_font
  end
end
