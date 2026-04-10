# frozen_string_literal: true

module PredictabilityEngine
  module SummaryVisualizer
    def self.metrics_html(work_items)
      completed = work_items.select(&:completed?)
      tp_avg = Calculators::Throughput.average(work_items)
      p50 = Calculators::CycleTime.percentile(work_items, 50)
      p85 = Calculators::CycleTime.percentile(work_items, 85)
      p95 = Calculators::CycleTime.percentile(work_items, 95)

      <<~HTML
        <h2>Flow Metrics Summary</h2>
        <ul>
          <li><strong>Total Items:</strong> #{work_items.size}</li>
          <li><strong>Completed Items:</strong> #{completed.size}</li>
          <li><strong>Average Throughput:</strong> #{tp_avg.round(2)} items/day</li>
          <li><strong>Cycle Time (p50):</strong> #{p50} days</li>
          <li><strong>Cycle Time (p85):</strong> #{p85} days</li>
          <li><strong>Cycle Time (p95):</strong> #{p95} days</li>
        </ul>
      HTML
    end

    def self.metrics_terminal(work_items)
      completed = work_items.select(&:completed?)
      tp_avg = Calculators::Throughput.average(work_items)
      p50 = Calculators::CycleTime.percentile(work_items, 50)
      p85 = Calculators::CycleTime.percentile(work_items, 85)
      p95 = Calculators::CycleTime.percentile(work_items, 95)

      [
        'Flow Metrics Summary',
        '--------------------',
        "Total Items: #{work_items.size}",
        "Completed Items: #{completed.size}",
        "Average Throughput: #{tp_avg.round(2)} items/day",
        '',
        'Cycle Time Percentiles:',
        "  50th Percentile: #{p50} days",
        "  85th Percentile: #{p85} days",
        "  95th Percentile: #{p95} days",
        ''
      ].join("\n")
    end
  end
end
