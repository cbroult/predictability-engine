# frozen_string_literal: true

require_relative 'helpers'

module PredictabilityEngine
  module SummaryVisualizer
    module Renderer
      def self.render_html_summary(work_items, metrics, percentiles)
        html = <<~HTML
          <h2>Flow Metrics Summary</h2>
          <ul>
            #{Helpers.metric_list(work_items, metrics)}
          </ul>
        HTML

        if metrics[:aging]
          html += <<~HTML
            <h3>Aging WIP Summary</h3>
            <ul>
              <li><strong>Active WIP:</strong> #{metrics[:aging][:count]} items</li>
              <li><strong>Average WIP Age:</strong> #{metrics[:aging][:avg_age]} days</li>
              <li><strong>Oldest Item Age:</strong> #{metrics[:aging][:max_age]} days</li>
            </ul>
          HTML
        end

        html += <<~HTML
          <h3>Cycle Time Percentiles</h3>
          <ul>
            #{Helpers.percentile_lines(metrics, percentiles, prefix: '<li><strong>', bold: '</strong>', suffix: '</li>')}
          </ul>
        HTML
        html
      end

      def self.render_terminal_summary(work_items, metrics, color, percentiles)
        bold, cyan, reset = Helpers.terminal_colors(color)
        out = [
          "#{bold}Flow Metrics Summary#{reset}",
          '--------------------',
          Helpers.metric_lines(work_items, metrics), ''
        ]

        out += aging_summary_lines(metrics, "#{cyan}Aging WIP Summary:#{reset}", '  ') if metrics[:aging]

        out += [
          "#{cyan}Cycle Time Percentiles:#{reset}",
          Helpers.percentile_lines(metrics, percentiles, prefix: '  '), ''
        ]
        out.join("\n")
      end

      def self.aging_summary_lines(metrics, title, prefix, bold = '')
        [
          title, '',
          "#{prefix}#{bold}Active WIP:#{bold} #{metrics[:aging][:count]} items",
          "#{prefix}#{bold}Average WIP Age:#{bold} #{metrics[:aging][:avg_age]} days",
          "#{prefix}#{bold}Oldest Item Age:#{bold} #{metrics[:aging][:max_age]} days", ''
        ]
      end

      def self.render_markdown_summary(work_items, metrics, percentiles)
        render_markup_summary(work_items, metrics, percentiles, { bold: '**', head2: '##', head3: '###' })
      end

      def self.render_confluence_summary(work_items, metrics, percentiles)
        render_markup_summary(work_items, metrics, percentiles, { bold: '*', head2: 'h2.', head3: 'h3.' })
      end

      def self.render_markup_summary(work_items, metrics, percentiles, styling)
        head2, head3, bold = styling.values_at(:head2, :head3, :bold)
        out = [
          "#{head2} Flow Metrics Summary", '',
          Helpers.metric_lines(work_items, metrics, prefix: '* ', bold: bold), ''
        ]

        out += aging_summary_lines(metrics, "#{head3} Aging WIP Summary", '* ', bold) if metrics[:aging]

        out += [
          "#{head3} Cycle Time Percentiles", '',
          Helpers.percentile_lines(metrics, percentiles, prefix: '* ', bold: bold)
        ]
        out.join("\n")
      end
    end
  end
end
