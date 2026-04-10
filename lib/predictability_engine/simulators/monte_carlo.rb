# frozen_string_literal: true

module PredictabilityEngine
  module Simulators
    class MonteCarlo
      DEFAULT_TRIALS = 10_000

      def self.when_will_it_be_done(backlog_count, historical_throughput, trials: DEFAULT_TRIALS)
        results = []

        # historical_throughput should be an array of daily counts
        return [] if historical_throughput.empty?

        trials.times do
          remaining = backlog_count
          days = 0

          while remaining.positive?
            sample = historical_throughput.sample
            remaining -= sample
            days += 1
          end

          results << days
        end

        results.sort!
      end

      def self.how_many_will_be_done(days_to_forecast, historical_throughput, trials: DEFAULT_TRIALS)
        results = []
        return [] if historical_throughput.empty?

        trials.times do
          total_done = 0
          days_to_forecast.times do
            total_done += historical_throughput.sample
          end
          results << total_done
        end

        results.sort!
      end

      def self.percentile(results, percentile_value)
        return nil if results.empty?

        index = (results.size * percentile_value / 100.0).ceil - 1
        results[index]
      end
    end
  end
end
