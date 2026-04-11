# frozen_string_literal: true

module PredictabilityEngine
  class Report
    attr_reader :items, :title

    CHART_CONFIG = {
      cycle_time_scatter: { title: 'Cycle Time Scatter Plot' },
      throughput_histogram: { title: 'Throughput Histogram' },
      forecasted_cfd_plot: { title: 'Forecasted Cumulative Flow Diagram', vega: :forecasted_cfd }
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
      }
    }.freeze

    def initialize(items, title: 'Predictability Report')
      @items = items
      @title = title
    end

    def self.generate_all(items)
      new(items, title: 'Full Predictability Dashboard')
    end

    def render(format, color: false)
      fmt = format.to_sym
      target = FORMAT_CONFIG.find { |k, v| k == fmt || v[:aliases]&.include?(fmt) }&.first || fmt
      method_name = "render_#{target}"

      raise ArgumentError, "Unsupported format: #{format}" unless respond_to?(method_name, true)

      send(method_name, color: color)
    end

    private

    def render_text_format(fmt, color: false)
      config = FORMAT_CONFIG[fmt]
      [
        config[:h1].call(@title),
        SummaryVisualizer.render(@items, fmt, color: color),
        *CHART_CONFIG.map do |id, cfg|
          content = TerminalVisualizer.send(id, @items, color: color)
          [config[:h2].call(cfg[:title]), config[:code].call(cfg[:title], content)].join("\n")
        end
      ].join("\n")
    end

    def render_terminal(color: false) = render_text_format(:terminal, color: color)
    def render_markdown(color: false) = render_text_format(:markdown, color: color)
    def render_confluence(color: false) = render_text_format(:confluence, color: color)

    def render_html(**_opts)
      charts = CHART_CONFIG.map do |id, cfg|
        vega_method = cfg[:vega] || id
        "<div class='section'><h2>#{cfg[:title]}</h2>" \
          "#{VegaVisualizer.send(vega_method, @items).to_html}</div>"
      end.join("\n")

      Visualizer.to_full_html(charts, @items, title: @title)
    end

    def render_pdf(**_opts)
      require 'prawn'
      items = @items
      title = @title

      Prawn::Document.new do |pdf|
        Report.send(:setup_pdf_font_on_doc, pdf)
        pdf.text title, size: 24, style: :bold
        pdf.move_down 20

        pdf.text SummaryVisualizer.metrics_terminal(items, color: false)

        CHART_CONFIG.each_key do |id|
          pdf.start_new_page
          pdf.text CHART_CONFIG[id][:title], size: 18, style: :bold
          pdf.move_down 10
          pdf.text TerminalVisualizer.send(id, items, color: false), size: 7
        end
      end.render
    end

    def self.setup_pdf_font_on_doc(pdf)
      mono_path = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
      bold_path = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'
      return unless File.exist?(mono_path) && File.exist?(bold_path)

      pdf.font_families.update('DejaVu' => { normal: mono_path, bold: bold_path })
      pdf.font 'DejaVu'
    end

    private_class_method :setup_pdf_font_on_doc
  end
end
