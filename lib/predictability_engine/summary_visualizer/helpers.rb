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
        {
          'Total Items': work_items.size,
          'Completed Items': metrics[:completed].size,
          'Average Throughput': "#{metrics[:tp_avg].round(2)} items/day"
        }
      end

      def self.terminal_colors(color)
        color ? ["\e[1m", "\e[36m", "\e[0m"] : ['', '', '']
      end
    end
  end
end
