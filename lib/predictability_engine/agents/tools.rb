# frozen_string_literal: true

require_relative '../visualizer'

module PredictabilityEngine
  module Agents
    class Tools
      include Langchain::ToolDefinition

      attr_reader :data_manager

      def initialize(data_manager)
        @data_manager = data_manager
      end

      desc 'Get average throughput for all work items'
      define_method :get_throughput_average do
        PredictabilityEngine::Calculators::Throughput.average(@data_manager.work_items)
      end

      desc 'Get visual charts (ASCII art) for Cycle Time, Throughput, and Forecasted CFD'
      define_method :get_visual_charts do
        {
          scatter_plot: PredictabilityEngine::Visualizer.cycle_time_scatter(@data_manager.work_items),
          throughput_histogram: PredictabilityEngine::Visualizer.throughput_histogram(@data_manager.work_items),
          cfd_plot: PredictabilityEngine::Visualizer.forecasted_cfd_plot(@data_manager.work_items)
        }
      end

      desc 'Get forecasted CFD summary (probabilistic projections for current WIP)'
      define_method :get_cfd_forecast do
        PredictabilityEngine::Calculators::Cfd.forecast_summary(@data_manager.work_items)
      end

      desc 'Get cycle time percentiles (p50, p85, p95)'
      define_method :get_cycle_time_percentiles do
        {
          p50: PredictabilityEngine::Calculators::CycleTime.percentile(@data_manager.work_items, 50),
          p85: PredictabilityEngine::Calculators::CycleTime.percentile(@data_manager.work_items, 85),
          p95: PredictabilityEngine::Calculators::CycleTime.percentile(@data_manager.work_items, 95)
        }
      end

      desc 'Forecast when items will be done based on backlog size'
      define_method :forecast_when_done do |backlog_count:|
        historical = PredictabilityEngine::Calculators::Throughput.daily(@data_manager.work_items).values
        results = PredictabilityEngine::Simulators::MonteCarlo.when_will_it_be_done(backlog_count.to_i, historical)

        {
          p50_days: PredictabilityEngine::Simulators::MonteCarlo.percentile(results, 50),
          p85_days: PredictabilityEngine::Simulators::MonteCarlo.percentile(results, 85),
          p95_days: PredictabilityEngine::Simulators::MonteCarlo.percentile(results, 95)
        }
      end

      desc 'Analyze Cumulative Flow Diagram for anomalies like growing WIP'
      define_method :analyze_cfd do
        cfd_data = PredictabilityEngine::Calculators::Cfd.calculate(@data_manager.work_items)
        recent = cfd_data.last(30)
        return { error: 'Not enough data' } if recent.empty?

        perform_cfd_trend_analysis(recent)
      end

      private

      def perform_cfd_trend_analysis(recent)
        wips = recent.map { |d| d[:wip] }
        departures = recent.map { |d| d[:departed] }

        growing_wip = wips.last > wips.first
        stagnant_tp = (departures.last - departures.first) <= 1

        build_cfd_analysis_response(wips.last, growing_wip, stagnant_tp, recent.size)
      end

      def build_cfd_analysis_response(current_wip, growing_wip, stagnant_tp, data_points)
        summary = "Current WIP is #{current_wip}. WIP trend is #{growing_wip ? 'growing' : 'stable'}. " \
                  "Throughput is #{stagnant_tp ? 'stagnant' : 'active'}."
        {
          current_wip: current_wip,
          wip_trend: growing_wip ? 'Growing' : 'Stable/Decreasing',
          stagnant_throughput: stagnant_tp,
          summary: summary,
          recent_data_points: data_points
        }
      end
    end
  end
end
