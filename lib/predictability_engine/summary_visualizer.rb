# frozen_string_literal: true

module PredictabilityEngine
  module SummaryVisualizer
    def self.metrics_html(work_items)
      m = calculate_metrics(work_items)

      <<~HTML
        <h2>Flow Metrics Summary</h2>
        <ul>
          <li><strong>Total Items:</strong> #{work_items.size}</li>
          <li><strong>Completed Items:</strong> #{m[:completed].size}</li>
          <li><strong>Average Throughput:</strong> #{m[:tp_avg].round(2)} items/day</li>
          <li><strong>Cycle Time (p50):</strong> #{m[:p50]} days</li>
          <li><strong>Cycle Time (p85):</strong> #{m[:p85]} days</li>
          <li><strong>Cycle Time (p95):</strong> #{m[:p95]} days</li>
        </ul>
      HTML
    end

    def self.metrics_terminal(work_items)
      m = calculate_metrics(work_items)

      [
        'Flow Metrics Summary',
        '--------------------',
        "Total Items: #{work_items.size}",
        "Completed Items: #{m[:completed].size}",
        "Average Throughput: #{m[:tp_avg].round(2)} items/day",
        '',
        'Cycle Time Percentiles:',
        "  50th Percentile: #{m[:p50]} days",
        "  85th Percentile: #{m[:p85]} days",
        "  95th Percentile: #{m[:p95]} days",
        ''
      ].join("\n")
    end

    def self.calculate_metrics(work_items)
      {
        completed: work_items.select(&:completed?),
        tp_avg: Calculators::Throughput.average(work_items),
        p50: Calculators::CycleTime.percentile(work_items, 50),
        p85: Calculators::CycleTime.percentile(work_items, 85),
        p95: Calculators::CycleTime.percentile(work_items, 95)
      }
    end

    private_class_method :calculate_metrics
  end
end
