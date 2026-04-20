# frozen_string_literal: true

module PredictabilityEngine
  module SummaryVisualizer
    module Helpers
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
        result = {
          'Total Items': work_items.size,
          'Completed Items': metrics[:completed].size,
          'Average Throughput': "#{metrics[:tp_avg].round(2)} items/day"
        }
        breakdown = priority_breakdown(metrics[:completed])
        result[:'Priority Breakdown'] = breakdown if breakdown
        result
      end

      PRIORITY_ORDER = %w[Highest High Medium Low Lowest].freeze
      private_constant :PRIORITY_ORDER

      def self.priority_breakdown(completed_items)
        counts = completed_items.filter_map(&:priority).tally
        return nil if counts.empty?

        ordered = PRIORITY_ORDER.filter_map { |p| "#{p} #{counts[p]}" if counts[p] }
        others  = (counts.keys - PRIORITY_ORDER).sort.map { |p| "#{p} #{counts[p]}" }
        (ordered + others).join(', ')
      end

      private_class_method :priority_breakdown

      def self.terminal_colors(color)
        color ? ["\e[1m", "\e[36m", "\e[0m"] : ['', '', '']
      end
    end
  end
end
