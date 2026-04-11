# frozen_string_literal: true

module PredictabilityEngine
  module SummaryVisualizer
    def self.metrics_html(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      render(work_items, :html, percentiles: percentiles)
    end

    def self.metrics_terminal(work_items, color: false, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      render(work_items, :terminal, color: color, percentiles: percentiles)
    end

    def self.metrics_markdown(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      render(work_items, :markdown, percentiles: percentiles)
    end

    def self.metrics_confluence(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      render(work_items, :confluence, percentiles: percentiles)
    end

    def self.render(work_items, format, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES, **options)
      stats = calculate_metrics(work_items, percentiles: percentiles)
      case format.to_sym
      when :html then Renderer.render_html_summary(work_items, stats, percentiles)
      when :terminal then Renderer.render_terminal_summary(work_items, stats, options[:color], percentiles)
      when :markdown then Renderer.render_markdown_summary(work_items, stats, percentiles)
      when :confluence then Renderer.render_confluence_summary(work_items, stats, percentiles)
      end
    end

    def self.calculate_metrics(work_items, percentiles: PredictabilityEngine::DEFAULT_PERCENTILES)
      metrics = {
        completed: PredictabilityEngine.completed_items(work_items),
        tp_avg: Calculators::Throughput.average(work_items)
      }
      percentiles.each do |p|
        metrics[:"p#{p}"] = Calculators::CycleTime.percentile(work_items, p)
      end
      metrics
    end

    private_class_method :calculate_metrics, :render
  end
end
