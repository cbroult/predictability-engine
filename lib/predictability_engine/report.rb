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
      chart = VegaVisualizer.dashboard(@items)
      Visualizer.to_full_html(chart, @items)
    end

    def render_pdf
      # For now, we return a simple string or a placeholder
      # In a real scenario, we might use prawn or similar
      '[PDF Rendering Placeholder] A PDF report would be generated here using the same metrics data.'
    end
  end
end
