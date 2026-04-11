# frozen_string_literal: true

module PredictabilityEngine
  class Report
    attr_reader :items, :title

    CHART_CONFIG = {
      aging_wip: { title: 'Aging Work In Progress' },
      forecasted_cfd_plot: { title: 'Forecasted Cumulative Flow Diagram', vega: :forecasted_cfd },
      cycle_time_scatter: { title: 'Cycle Time Scatter Plot' },
      throughput_histogram: { title: 'Throughput Histogram' }
    }.freeze

    FORMAT_CONFIG = {
      terminal: {
        h1: ->(t) { "=== #{t} ===" },
        h2: ->(t) { "\n=== #{t} ===" },
        code: ->(_t, c) { c },
        aliases: %i[console ascii]
      },
      markdown: {
        h1: ->(t) { "# #{t}\n" },
        h2: ->(t) { "\n## #{t}" },
        code: ->(_t, c) { "```\n#{c}\n```" },
        aliases: [:md]
      },
      confluence: {
        h1: ->(t) { "h1. #{t}\n" },
        h2: ->(t) { "\nh2. #{t}" },
        code: ->(t, c) { "{code:title=#{t}}\n#{c}\n{code}" },
        aliases: [:conf]
      },
      landscape: {
        aliases: [:dashboard],
        layout: :landscape
      },
      a3_landscape: {
        format: 'A3',
        landscape: true,
        layout: :landscape
      }
    }.freeze

    def initialize(items, title: 'Predictability Report')
      @items = items
      @title = title
    end

    def self.generate_all(items)
      new(items, title: 'Full Predictability Dashboard')
    end

    def render(format, layout: nil, color: false)
      config = find_format_config(format)&.last
      method_name = "render_#{find_format_config(format)&.first || format.to_sym}"

      raise ArgumentError, "Unsupported format: #{format}" unless respond_to?(method_name, true)

      opts = { layout: effective_layout(layout, config), color: color }
      opts[:format] = config[:format] if config&.key?(:format)
      opts[:landscape] = config[:landscape] if config&.key?(:landscape)

      send(method_name, **opts)
    end

    private

    def find_format_config(format)
      fmt = format.to_sym
      FORMAT_CONFIG.find { |k, v| k == fmt || v[:aliases]&.include?(fmt) }
    end

    def effective_layout(layout, config)
      layout || config&.dig(:layout) || :standard
    end

    def render_text_format(fmt, color: false)
      config = FORMAT_CONFIG[fmt]
      [
        config[:h1].call(@title),
        SummaryVisualizer.render(@items, fmt, color: color),
        *CHART_CONFIG.map do |chart_id, cfg|
          render_chart_section(chart_id, cfg, config, fmt, color: color)
        end
      ].join("\n")
    end

    def render_chart_section(chart_id, cfg, config, fmt, color: false)
      text_formats = %i[markdown confluence]
      mermaid = text_formats.include?(fmt) && MermaidVisualizer.respond_to?(chart_id)
      title = config[:h2].call(cfg[:title])

      if mermaid
        mermaid_code = MermaidVisualizer.send(chart_id, @items)
        macro = 'mermaid'
        wrap = fmt == :confluence ? ["{#{macro}}", "{#{macro}}"] : ["```#{macro}", '```']
        [title, wrap[0], mermaid_code, wrap[1]].join("\n")
      else
        # Force color: false for Markdown/Confluence to avoid ANSI codes in text reports
        force_color = text_formats.include?(fmt) ? false : color
        content = TerminalVisualizer.send(chart_id, @items, color: force_color)
        [title, config[:code].call(cfg[:title], content)].join("\n")
      end
    end

    def render_terminal(color: false, **_opts) = render_text_format(:terminal, color: color)
    def render_markdown(color: false, **_opts) = render_text_format(:markdown, color: color)
    def render_confluence(color: false, **_opts) = render_text_format(:confluence, color: color)

    def render_html(layout: :standard, **_opts)
      charts = CHART_CONFIG.map do |chart_id, cfg|
        vega_method = cfg[:vega] || chart_id
        if layout == :landscape
          { title: cfg[:title], chart: VegaVisualizer.send(vega_method, @items) }
        else
          "<div class='section'><h2>#{cfg[:title]}</h2>" \
            "#{VegaVisualizer.send(vega_method, @items).to_html}</div>"
        end
      end

      Visualizer.to_full_html(charts, @items, title: @title, layout: layout)
    end

    def render_landscape(layout: :landscape, **) = render_html(layout: layout, **)
    def render_a3_landscape(**) = render_pdf(**)

    def render_pdf(layout: :landscape, high_fidelity: true, format: 'A4', landscape: true, **_opts)
      high_fidelity ? render_pdf_playwright(layout: layout, format: format, landscape: landscape) : render_pdf_prawn
    rescue LoadError, StandardError => e
      warn "High-fidelity PDF generation failed: #{e.message}. Falling back to Prawn."
      render_pdf_prawn
    end

    def render_pdf_playwright(layout: :landscape, format: 'A4', landscape: true)
      require 'playwright'
      html = render_html(layout: layout)
      temp_html = "tmp/report_#{object_id}.html"
      FileUtils.mkdir_p('tmp')
      File.write(temp_html, html)
      pdf_data = nil

      root = File.expand_path('../..', __dir__)
      playwright_bin = if File.exist?("#{root}/node_modules/.bin/playwright")
                         "#{root}/node_modules/.bin/playwright"
                       else
                         'npx playwright'
                       end

      # Ensure Playwright finds the browsers even in isolated environments like Aruba
      ENV['PLAYWRIGHT_BROWSERS_PATH'] ||= File.expand_path('~/.cache/ms-playwright')

      Playwright.create(playwright_cli_executable_path: playwright_bin) do |playwright|
        playwright.chromium.launch do |browser|
          page = browser.new_page(viewport: { width: 1280, height: 720 })
          page.goto("file://#{File.expand_path(temp_html)}")
          # Wait for Vega to render
          sleep 2
          pdf_data = page.pdf(
            format: format,
            landscape: landscape,
            printBackground: true,
            margin: { top: '0', right: '0', bottom: '0', left: '0' }
          )
        end
      end
      FileUtils.rm_f(temp_html)
      pdf_data
    ensure
      FileUtils.rm_f(temp_html)
    end

    def render_pdf_prawn(**_opts)
      require 'prawn'
      items = @items
      title = @title

      Prawn::Document.new do |pdf|
        Report.send(:setup_pdf_font_on_doc, pdf)
        pdf.text title, size: 24, style: :bold
        pdf.move_down 20

        pdf.text SummaryVisualizer.metrics_terminal(items, color: false)

        CHART_CONFIG.each_key do |chart_id|
          pdf.start_new_page
          pdf.text CHART_CONFIG[chart_id][:title], size: 18, style: :bold
          pdf.move_down 20
          PdfVisualizer.draw_chart(pdf, chart_id, items)
          pdf.move_down 20
          pdf.text 'ASCII Representation:', size: 10, style: :bold
          pdf.move_down 5
          pdf.text TerminalVisualizer.send(chart_id, items, color: false), size: 7
        end
      end.render
    end

    def self.setup_pdf_font_on_doc(pdf)
      mono = find_font(['/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
                        '/System/Library/Fonts/Supplemental/Courier New.ttf',
                        '/Library/Fonts/Courier New.ttf',
                        'C:/Windows/Fonts/cour.ttf'])
      bold = find_font(['/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf',
                        '/System/Library/Fonts/Supplemental/Courier New Bold.ttf',
                        '/Library/Fonts/Courier New Bold.ttf',
                        'C:/Windows/Fonts/courbd.ttf'])

      return unless mono && bold

      pdf.font_families.update('CustomMono' => { normal: mono, bold: bold })
      pdf.font 'CustomMono'
    end

    def self.find_font(paths)
      paths.find { |p| File.exist?(p) }
    end

    private_class_method :setup_pdf_font_on_doc, :find_font
  end
end
