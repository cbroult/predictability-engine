# frozen_string_literal: true

require 'fileutils'
require_relative 'report/constants'
require_relative 'report/image_generator'
require_relative 'report/text_renderer'

module PredictabilityEngine
  class Report # rubocop:disable Metrics/ClassLength
    include Constants

    PRIORITY_SORT = lambda do |values|
      values.sort_by { |v| [Constants::PRIORITY_ORDER.index(v) || Constants::PRIORITY_ORDER.size, v] }
    end

    FACETS = [
      { key: :priority, label: 'Priority', accessor: :priority, dirname: 'priorities',
        sort: PRIORITY_SORT },
      { key: :type, label: 'Type', accessor: :type, dirname: 'types',
        sort: lambda(&:sort) }
    ].freeze

    attr_reader :items, :title, :percentiles, :images_path, :type, :priority

    def initialize(items, title: 'Predictability Report', percentiles: PredictabilityEngine::DEFAULT_PERCENTILES,
                   type: nil, priority: nil)
      @type = type
      @priority = priority
      @items = filter_by_facets(items)
      @title = title
      @percentiles = percentiles
      @images_path = nil
    end

    def self.generate_all(items)
      reports = { all: new(items, title: 'Full Predictability Dashboard') }
      FACETS.each do |facet|
        values = facet_values(items, facet)
        next unless values.size > 1

        reports[facet[:key]] = values.to_h do |val|
          [val, new(items, title: "Dashboard: #{val}", facet[:key] => val)]
        end
      end
      reports
    end

    def self.facet_values(items, facet)
      raw = items.map { |i| i.public_send(facet[:accessor]) || 'Unspecified' }.uniq
      facet[:sort].call(raw)
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
      PredictabilityEngine.logger.warn { "Chart image generation failed: #{e.message}. Falling back to Mermaid/ASCII." }
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

    def with_report_temp_html(layout: :landscape)
      temp_html = "tmp/report_#{object_id}.html"
      FileUtils.mkdir_p('tmp')
      File.write(temp_html, render_html(layout: layout))
      yield temp_html
    ensure
      FileUtils.rm_f(temp_html) if temp_html
    end

    def playwright_bin
      root = File.expand_path('../..', __dir__)
      unless ENV['PLAYWRIGHT_BROWSERS_PATH']
        require 'etc'
        real_home = begin
          Etc.getpwuid.dir
        rescue StandardError
          Dir.home
        end
        ENV['PLAYWRIGHT_BROWSERS_PATH'] = File.expand_path('.cache/ms-playwright', real_home)
      end
      File.exist?("#{root}/node_modules/.bin/playwright") ? "#{root}/node_modules/.bin/playwright" : 'npx playwright'
    end

    def playwright_chromium_launch_opts
      exe = ENV.fetch('PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH', nil)
      return {} unless exe

      # System Chromium (e.g. Alpine apk) needs --no-sandbox in Docker containers.
      { executablePath: exe, chromiumSandbox: false }
    end

    def pdf_viewport_size(format, landscape)
      res = RESOLUTION_CONFIG[format.to_s.downcase]
      if res
        return landscape ? res : [res[1], res[0]]
      end

      sizes = { 'A4' => [794, 1123], 'A3' => [1123, 1587] }
      w, h = sizes[format.to_s.upcase] || sizes[DEFAULT_SIZE.to_s.upcase]
      landscape ? [h, w] : [w, h]
    end

    def render_image_link(chart_id, fmt)
      rel_path = "images/#{chart_id}.png"
      fmt == :confluence ? "!#{rel_path}!" : "![](#{rel_path})"
    end

    private

    def filter_by_facets(items)
      FACETS.reduce(items) do |acc, facet|
        filter_val = instance_variable_get("@#{facet[:key]}")
        next acc unless filter_val

        acc.select { |i| (i.public_send(facet[:accessor]) || 'Unspecified') == filter_val }
      end
    end

    def render_ppt_multi_slide
      require 'powerpoint'
      base_dir = "tmp/ppt_#{object_id}"
      FileUtils.mkdir_p(base_dir)
      generate_chart_images(base_dir)

      deck = Powerpoint::Presentation.new
      deck.add_intro(@title, "Generated on #{PredictabilityEngine.format_datetime(Time.now)}")

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

    def render_png(layout: :landscape, size: DEFAULT_SIZE, **)
      res = RESOLUTION_CONFIG[size.to_s.downcase] || RESOLUTION_CONFIG[DEFAULT_SIZE]
      with_report_temp_html(layout: layout) do |temp_html|
        png_data = nil
        with_playwright_page(temp_html, width: res[0], height: res[1]) do |page|
          png_data = page.screenshot
        end
        png_data
      end
    end

    def render_ppt(size: DEFAULT_SIZE, **_opts)
      require 'powerpoint'
      res = RESOLUTION_CONFIG[size.to_s.downcase] || RESOLUTION_CONFIG[DEFAULT_SIZE]
      temp_img = "tmp/dashboard_#{object_id}.png"
      ppt_file = "tmp/dashboard_#{object_id}.pptx"

      with_report_temp_html(layout: :landscape) do |temp_html|
        capture_screenshot(temp_html, temp_img, width: res[0], height: res[1])

        deck = Powerpoint::Presentation.new
        deck.add_pictorial_slide(@title, temp_img)
        deck.save(ppt_file)
        File.binread(ppt_file)
      end
    rescue StandardError => e
      PredictabilityEngine.logger.warn do
        "High-fidelity PPT generation failed: #{e.message}. Falling back to multi-slide."
      end
      render_ppt_multi_slide
    ensure
      FileUtils.rm_f(temp_img) if temp_img
      FileUtils.rm_f(ppt_file) if ppt_file
    end

    def capture_screenshot(html_path, img_path, width: 1280, height: 720)
      with_playwright_page(html_path, width: width, height: height) do |page|
        page.screenshot(path: img_path, fullPage: true)
      end
    end

    def render_pdf(layout: :landscape, high_fidelity: true, format: nil, size: DEFAULT_SIZE, landscape: true, **_opts) # rubocop:disable Metrics/ParameterLists
      fmt = format || size
      high_fidelity ? render_pdf_playwright(layout: layout, format: fmt, landscape: landscape) : render_pdf_prawn
    rescue StandardError => e
      PredictabilityEngine.logger.warn { "High-fidelity PDF generation failed: #{e.message}. Falling back to Prawn." }
      render_pdf_prawn
    end

    def render_pdf_playwright(layout: :landscape, format: DEFAULT_SIZE, landscape: true)
      with_report_temp_html(layout: layout) do |temp_html|
        capture_pdf(temp_html, format, landscape)
      end
    end

    def capture_pdf(html_path, format, landscape)
      w, h = pdf_viewport_size(format, landscape)
      pdf_data = nil
      with_playwright_page(html_path, width: w, height: h) do |page|
        pdf_opts = { landscape: landscape, printBackground: true,
                     pageRanges: '1',
                     margin: { top: '0', right: '0', bottom: '0', left: '0' } }

        standard_formats = %w[Letter Legal Tabloid Ledger A0 A1 A2 A3 A4 A5 A6]
        if standard_formats.include?(format.to_s.capitalize)
          pdf_opts[:format] = format.to_s.capitalize
        elsif standard_formats.include?(format.to_s.upcase)
          pdf_opts[:format] = format.to_s.upcase
        else
          pdf_opts[:width] = "#{w}px"
          pdf_opts[:height] = "#{h}px"
        end

        pdf_data = page.pdf(**pdf_opts)
      end
      pdf_data
    end

    def with_playwright_page(html_path, width: 1280, height: 720)
      require 'playwright'
      Playwright.create(playwright_cli_executable_path: playwright_bin) do |p|
        p.chromium.launch(**playwright_chromium_launch_opts) do |browser|
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
