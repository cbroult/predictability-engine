# frozen_string_literal: true

module PredictabilityEngine
  module SummaryVisualizer
    module Renderer
      def self.render_html_summary(work_items, metrics, percentiles)
        <<~HTML
          <h2>Flow Metrics Summary</h2>
          <ul>
            #{metric_list(work_items, metrics)}
          </ul>
          <h3>Cycle Time Percentiles</h3>
          <ul>
            #{percentile_lines(metrics, percentiles, prefix: '<li><strong>', bold: '</strong>', suffix: '</li>')}
          </ul>
        HTML
      end

      def self.render_terminal_summary(work_items, metrics, color, percentiles)
        bold, cyan, reset = terminal_colors(color)
        [
          "#{bold}Flow Metrics Summary#{reset}",
          '--------------------',
          metric_lines(work_items, metrics), '',
          "#{cyan}Cycle Time Percentiles:#{reset}",
          percentile_lines(metrics, percentiles, prefix: '  '), ''
        ].join("\n")
      end

      def self.render_markdown_summary(work_items, metrics, percentiles)
        [
          '## Flow Metrics Summary', '',
          metric_lines(work_items, metrics, prefix: '* ', bold: '**'), '',
          '### Cycle Time Percentiles', '',
          percentile_lines(metrics, percentiles, prefix: '* ', bold: '**')
        ].join("\n")
      end

      def self.render_confluence_summary(work_items, metrics, percentiles)
        [
          'h2. Flow Metrics Summary', '',
          metric_lines(work_items, metrics, prefix: '* ', bold: '*'), '',
          'h3. Cycle Time Percentiles', '',
          percentile_lines(metrics, percentiles, prefix: '* ', bold: '*')
        ].join("\n")
      end

      def self.metric_lines(work_items, metrics, prefix: '', bold: '')
        shared_metrics(work_items, metrics).map { |k, v| "#{prefix}#{bold}#{k}:#{bold} #{v}" }.join("\n")
      end

      def self.metric_list(work_items, metrics)
        shared_metrics(work_items, metrics).map { |k, v| "<li><strong>#{k}:</strong> #{v}</li>" }.join("\n")
      end

      def self.percentile_lines(metrics, percentiles, prefix: '', bold: '', suffix: '')
        percentiles.map do |p|
          "#{prefix}#{bold}#{p}th Percentile:#{bold} #{metrics[:"p#{p}"]} days#{suffix}"
        end.join("\n")
      end

      def self.shared_metrics(work_items, metrics)
        {
          'Total Items': work_items.size,
          'Completed Items': metrics[:completed].size,
          'Average Throughput': "#{metrics[:tp_avg].round(2)} items/day"
        }
      end

      def self.terminal_colors(color)
        color ? ["\e[1m", "\e[36m", "\e[0m"] : ['', '', '']
      end

      private_class_method :terminal_colors, :metric_lines, :metric_list, :percentile_lines, :shared_metrics
    end
  end
end
