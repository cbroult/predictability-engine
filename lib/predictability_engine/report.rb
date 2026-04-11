# frozen_string_literal: true

module PredictabilityEngine
  class Report
    attr_reader :items, :title

    def initialize(items, title: 'Predictability Report')
      @items = items
      @title = title
    end

    def self.generate_all(items)
      new(items, title: 'Full Predictability Dashboard')
    end

    def render(format, color: false)
      case format.to_sym
      when :terminal, :console, :ascii
        render_terminal(color: color)
      when :html
        render_html
      when :markdown, :md
        render_markdown
      when :confluence, :conf
        render_confluence
      when :pdf
        render_pdf
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end
    end

    private

    def render_terminal(color: false)
      [
        "=== #{@title} ===",
        SummaryVisualizer.metrics_terminal(@items, color: color),
        "\n=== Cycle Time Scatter Plot ===",
        TerminalVisualizer.cycle_time_scatter(@items, color: color),
        "\n=== Throughput Histogram ===",
        TerminalVisualizer.throughput_histogram(@items, color: color),
        "\n=== Forecasted Cumulative Flow Diagram ===",
        TerminalVisualizer.forecasted_cfd_plot(@items, color: color)
      ].join("\n")
    end

    def render_html
      charts = [
        "<div class='section'><h2>Cycle Time Scatter Plot</h2>" \
        "#{VegaVisualizer.cycle_time_scatter(@items).to_html}</div>",
        "<div class='section'><h2>Throughput Histogram</h2>" \
        "#{VegaVisualizer.throughput_histogram(@items).to_html}</div>",
        "<div class='section'><h2>Forecasted Cumulative Flow Diagram</h2>" \
        "#{VegaVisualizer.forecasted_cfd(@items).to_html}</div>"
      ].join("\n")

      Visualizer.to_full_html(charts, @items, title: @title)
    end

    def render_markdown
      [
        "# #{@title}",
        '',
        SummaryVisualizer.metrics_markdown(@items),
        '',
        '## Cycle Time Scatter Plot',
        '```',
        TerminalVisualizer.cycle_time_scatter(@items, color: false),
        '```',
        '',
        '## Throughput Histogram',
        '```',
        TerminalVisualizer.throughput_histogram(@items, color: false),
        '```',
        '',
        '## Forecasted Cumulative Flow Diagram',
        '```',
        TerminalVisualizer.forecasted_cfd_plot(@items, color: false),
        '```'
      ].join("\n")
    end

    def render_confluence
      [
        "h1. #{@title}",
        '',
        SummaryVisualizer.metrics_confluence(@items),
        '',
        'h2. Cycle Time Scatter Plot',
        '{code:title=Cycle Time Scatter Plot}',
        TerminalVisualizer.cycle_time_scatter(@items, color: false),
        '{code}',
        '',
        'h2. Throughput Histogram',
        '{code:title=Throughput Histogram}',
        TerminalVisualizer.throughput_histogram(@items, color: false),
        '{code}',
        '',
        'h2. Forecasted Cumulative Flow Diagram',
        '{code:title=Forecasted Cumulative Flow Diagram}',
        TerminalVisualizer.forecasted_cfd_plot(@items, color: false),
        '{code}'
      ].join("\n")
    end

    def render_pdf
      require 'prawn'
      items = @items
      title = @title

      Prawn::Document.new do |pdf|
        setup_pdf_font(pdf)
        pdf.text title, size: 24, style: :bold
        pdf.move_down 20

        pdf.text SummaryVisualizer.metrics_terminal(items, color: false)

        %i[cycle_time_scatter throughput_histogram forecasted_cfd_plot].each do |chart|
          pdf.start_new_page
          pdf.text chart.to_s.split('_').map(&:capitalize).join(' '), size: 18, style: :bold
          pdf.move_down 10
          chart_text = TerminalVisualizer.send(chart, items, color: false)
          pdf.text chart_text, size: 7
        end
      end.render
    end

    def setup_pdf_font(pdf)
      mono_path = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
      bold_path = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'
      return unless File.exist?(mono_path) && File.exist?(bold_path)

      pdf.font_families.update('DejaVu' => {
                                 normal: mono_path,
                                 bold: bold_path
                               })
      pdf.font 'DejaVu'
    end
  end
end
