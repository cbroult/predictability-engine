# frozen_string_literal: true

module PredictabilityEngine
  module Simulators
    class MonteCarlo
      DEFAULT_TRIALS = 10_000

      def self.when_will_it_be_done(backlog_count, historical_throughput, trials: DEFAULT_TRIALS)
        return [] if historical_throughput.empty?

        run_simulation(trials) do
          remaining = backlog_count
          days = 0

          while remaining.positive?
            remaining -= historical_throughput.sample
            days += 1
          end

          days
        end
      end

      def self.how_many_will_be_done(days_to_forecast, historical_throughput, trials: DEFAULT_TRIALS)
        return [] if historical_throughput.empty?

        run_simulation(trials) do
          total_done = 0
          days_to_forecast.times do
            total_done += historical_throughput.sample
          end
          total_done
        end
      end

      def self.percentile(results, percentile_value)
        return nil if results.empty?

        index = (results.size * percentile_value / 100.0).ceil - 1
        results[index]
      end

      def self.run_simulation(trials)
        results = []
        trials.times { results << yield }
        results.sort!
      end

      private_class_method :run_simulation
    end
  end
end
