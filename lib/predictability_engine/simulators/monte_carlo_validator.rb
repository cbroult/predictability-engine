# frozen_string_literal: true

module PredictabilityEngine
  module Simulators
    class MonteCarloValidator
      DEFAULT_VALIDATION_TRIALS = 200
      MIN_COMPLETED_ITEMS = 10

      # Hindcast calibration: randomly samples historical as-of dates, runs the primary
      # Monte Carlo at each, and checks whether the predicted percentile days covered
      # the actual outcome. Returns coverage ratios per percentile, or nil when there
      # is insufficient data for any valid trial.
      def self.calibration(
        work_items,
        percentiles: PredictabilityEngine::DEFAULT_PERCENTILES,
        validation_trials: DEFAULT_VALIDATION_TRIALS,
        primary_trials: MonteCarlo::DEFAULT_TRIALS
      )
        completed = work_items.select(&:completed?)
        dates = candidate_dates(completed, validation_trials)
        return nil if dates.empty?

        trial_results = dates.map { |d| run_trial(completed, d, percentiles, primary_trials) }
        aggregate_coverage(trial_results, percentiles, dates.size)
      end

      def self.date_range(completed)
        sorted_ends = completed.map(&:end_date).sort
        return nil if sorted_ends.size < MIN_COMPLETED_ITEMS

        earliest_valid = sorted_ends[MIN_COMPLETED_ITEMS - 1]
        latest_valid = sorted_ends.last - 1
        return nil if earliest_valid > latest_valid

        [earliest_valid, latest_valid]
      end

      def self.candidate_dates(completed, count)
        range = date_range(completed)
        return [] unless range

        earliest, latest = range
        span = (latest - earliest).to_i
        return [] if span.zero?

        srand(7)
        dates = count.times.map { earliest + rand(span + 1) }
        srand
        dates
      end

      def self.run_trial(completed, as_of_date, percentiles, primary_trials)
        in_flight = completed.select { |i| i.in_progress?(as_of_date) }
        historical = valid_historical(completed, as_of_date, in_flight) or return nil

        actual_days = (in_flight.map(&:end_date).max - as_of_date).to_i
        results = MonteCarlo.when_will_it_be_done(in_flight.size, historical, trials: primary_trials)

        percentiles.to_h { |p| [p, actual_days <= MonteCarlo.percentile(results, p)] }
      end

      def self.valid_historical(completed, as_of_date, in_flight)
        return nil if in_flight.empty?

        historical_items = completed.select { |i| i.end_date <= as_of_date }
        return nil if historical_items.size < MIN_COMPLETED_ITEMS

        historical = Calculators::Throughput.daily(historical_items).values
        historical unless historical.all?(&:zero?)
      end

      def self.aggregate_coverage(trial_results, percentiles, total_sampled)
        valid = trial_results.compact
        return nil if valid.empty?

        coverage = percentiles.to_h do |p|
          [p, valid.count { |t| t[p] }.to_f / valid.size]
        end
        coverage.merge(trials_run: valid.size, trials_skipped: total_sampled - valid.size)
      end

      private_class_method :date_range, :candidate_dates, :run_trial, :valid_historical, :aggregate_coverage
    end
  end
end
