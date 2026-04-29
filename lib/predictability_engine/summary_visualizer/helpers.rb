# frozen_string_literal: true

module PredictabilityEngine
  module SummaryVisualizer
    module Helpers
      def self.metric_lines(work_items, metrics, prefix: '', bold: '')
        shared_metrics(work_items, metrics).map { |k, v| "#{prefix}#{bold}#{k}:#{bold} #{v}" }.join("\n")
      end

      def self.metric_list(work_items, metrics)
        shared_metrics(work_items, metrics).map do |k, v|
          if v.to_s.include?("\n")
            items = v.to_s.strip.split("\n").map { |e| "<li>#{e.strip}</li>" }.join
            "<li class='breakdown'><strong>#{k}:</strong><ul>#{items}</ul></li>"
          else
            "<li><strong>#{k}:</strong> <span class='metric-value'>#{v}</span></li>"
          end
        end.join("\n")
      end

      def self.percentile_lines(metrics, percentiles, prefix: '', bold: '', suffix: '')
        percentiles.map do |p|
          "#{prefix}#{bold}#{p}th Percentile:#{bold} #{metrics[:"p#{p}"]} days#{suffix}"
        end.join("\n")
      end

      def self.shared_metrics(work_items, metrics)
        result = {
          'Total Items': work_items.size,
          'Completed Items': metrics[:completed].size,
          'Average Throughput': "#{metrics[:tp_avg].round(2)} items/day"
        }
        Report::FACETS.each do |facet|
          breakdown = facet_breakdown(metrics[:completed], facet)
          result[:"#{facet[:label]} Breakdown"] = breakdown if breakdown
        end
        result
      end

      def self.facet_breakdown(completed_items, facet)
        counts = completed_items.filter_map { |i| i.public_send(facet[:accessor]) }.tally
        return nil if counts.size <= 1

        "\n#{ordered_facet_entries(counts, facet).map { |e| "  #{e}" }.join("\n")}"
      end

      def self.ordered_facet_entries(counts, facet)
        return priority_ordered_entries(counts) if facet[:key] == :priority

        counts.sort_by { |_, v| -v }.map { |k, v| "#{k}: #{v}" }
      end

      def self.priority_ordered_entries(counts)
        priority_order = Report::Constants::PRIORITY_ORDER
        ordered = priority_order.filter_map { |p| "#{p}: #{counts[p]}" if counts[p] }
        others  = (counts.keys - priority_order).sort.map { |p| "#{p}: #{counts[p]}" }
        ordered + others
      end

      private_class_method :facet_breakdown, :ordered_facet_entries, :priority_ordered_entries

      def self.terminal_colors(color)
        color ? ["\e[1m", "\e[36m", "\e[0m"] : ['', '', '']
      end
    end
  end
end
