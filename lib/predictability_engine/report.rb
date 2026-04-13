# frozen_string_literal: true

require 'fileutils'
require_relative 'report/constants'
require_relative 'report/image_generator'
require_relative 'report/text_renderer'

module PredictabilityEngine
  class Report
    include Constants

    attr_reader :items, :title, :percentiles, :images_path, :type

    def initialize(items, title: 'Predictability Report', percentiles: PredictabilityEngine::DEFAULT_PERCENTILES,
                   type: nil)
      @type = type
      @items = type ? items.select { |i| (i.type || 'Unspecified') == type } : items
      @title = title
      @percentiles = percentiles
      @images_path = nil
    end

    def self.generate_all(items)
      reports = { all: new(items, title: 'Full Predictability Dashboard') }
      types = items.map { |i| i.type || 'Unspecified' }.uniq
      if types.size > 1
        types.each do |type|
          reports[type] = new(items, title: "Dashboard: #{type}", type: type)
        end
      end
      reports
    end

    def render(format, layout: nil, color: false, **extra_opts)
      config = find_format_config(format)&.last
      method_name = "render_#{find_format_config(format)&.first || format.to_sym}"
      raise ArgumentError, "Unsupported format: #{format}" unless respond_to?(method_name, true)

      opts = { layout: effective_layout(layout, config), color: color }.merge(extra_opts)
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

    def render_html(layout: :landscape, sub_reports: nil, **)
      charts = CHART_CONFIG.map do |id, cfg|
        chart = VegaVisualizer.send(cfg[:vega] || id, @items,
                                    title: nil,
                                    percentiles: @percentiles)
        { title: cfg[:title], chart: chart }
      end
      Visualizer.to_full_html(charts, @items, title: @title, layout: layout, percentiles: @percentiles,
                                              sub_reports: sub_reports)
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

    def render_ppt_multi_slide
      require 'powerpoint'
      base_dir = "tmp/ppt_#{object_id}"
      FileUtils.mkdir_p(base_dir)
      generate_chart_images(base_dir)

      deck = Powerpoint::Presentation.new
      deck.add_intro(@title, "Generated on #{Time.now.strftime('%Y-%m-%d %H:%M')}")

      metrics = SummaryVisualizer.metrics_terminal(@items, color: false, percentiles: @percentiles)
      deck.add_textual_slide('Flow Metrics Summary', metrics.split("\n").map(&:strip).reject(&:empty?))

      CHART_CONFIG.each_key do |id|
        img = File.join(@images_path, "#{id}.png") if @images_path
        deck.add_pictorial_slide(CHART_CONFIG[id][:title], img) if img && File.exist?(img)
      end

      ppt_file = File.join(base_dir, 'dashboard.pptx')
      deck.save(ppt_file)
      File.binread(ppt_file)
    ensure
      FileUtils.rm_rf(base_dir) if base_dir
    end

    def find_format_config(format)
      fmt = format.to_sym
      FORMAT_CONFIG.find { |k, v| k == fmt || v[:aliases]&.include?(fmt) }
    end

    def effective_layout(layout, config) = (layout || config&.dig(:layout) || :landscape).to_sym

    %i[terminal markdown confluence].each do |f|
      define_method("render_#{f}") { |**o| TextRenderer.render(self, f, **o) }
    end

    def render_landscape(layout: :landscape, **) = render_html(layout: layout, **)
    def render_a3_landscape(**) = render_pdf(**)

    def render_ppt(**_opts)
      require 'powerpoint'
      require 'playwright'

      temp_html = "tmp/report_#{object_id}.html"
      temp_img = "tmp/dashboard_#{object_id}.png"
      ppt_file = "tmp/dashboard_#{object_id}.pptx"
      FileUtils.mkdir_p('tmp')
      File.write(temp_html, render_html(layout: :landscape))

      capture_screenshot(temp_html, temp_img)

      deck = Powerpoint::Presentation.new
      deck.add_pictorial_slide(@title, temp_img)
      deck.save(ppt_file)
      File.binread(ppt_file)
    rescue StandardError => e
      warn "High-fidelity PPT generation failed: #{e.message}. Falling back to multi-slide."
      render_ppt_multi_slide
    ensure
      FileUtils.rm_f(temp_html) if temp_html
      FileUtils.rm_f(temp_img) if temp_img
      FileUtils.rm_f(ppt_file) if ppt_file
    end

    def capture_screenshot(html_path, img_path)
      with_playwright_page(html_path) do |page|
        page.screenshot(path: img_path, fullPage: true)
      end
    end

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
      capture_pdf(temp_html, format, landscape)
    ensure
      FileUtils.rm_f(temp_html)
    end

    def capture_pdf(html_path, format, landscape)
      w, h = pdf_viewport_size(format, landscape)
      pdf_data = nil
      with_playwright_page(html_path, width: w, height: h) do |page|
        pdf_data = page.pdf(format: format, landscape: landscape, printBackground: true,
                            pageRanges: '1',
                            margin: { top: '0', right: '0', bottom: '0', left: '0' })
      end
      pdf_data
    end

    def with_playwright_page(html_path, width: 1280, height: 720)
      Playwright.create(playwright_cli_executable_path: playwright_bin) do |p|
        p.chromium.launch do |browser|
          page = browser.new_page(viewport: { width: width, height: height })
          page.goto("file://#{File.expand_path(html_path)}")
          sleep 2 # wait for Vega to render
          yield page
        end
      end
    end

    def render_pdf_prawn(**)
      require 'prawn'
      Prawn::Document.new(page_layout: :landscape, margin: 30) do |pdf|
        Report.send(:setup_pdf_font_on_doc, pdf)
        pdf.text @title, size: 20, style: :bold
        pdf.move_down 15

        pdf.define_grid(columns: 3, rows: 2, gutter: 15)

        pdf.grid([0, 0], [1, 0]).bounding_box do
          pdf.text 'Flow Metrics Summary', size: 14, style: :bold
          pdf.move_down 10
          pdf.text SummaryVisualizer.metrics_terminal(@items, color: false, percentiles: @percentiles), size: 8
        end

        charts = CHART_CONFIG.keys
        [[0, 1], [0, 2], [1, 1], [1, 2]].each_with_index do |grid_pos, i|
          id = charts[i]
          next unless id

          pdf.grid(*grid_pos).bounding_box do
            pdf.text CHART_CONFIG[id][:title], size: 10, style: :bold
            pdf.move_down 5
            PdfVisualizer.draw_chart(pdf, id, @items, percentiles: @percentiles)
          end
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
