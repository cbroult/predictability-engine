# frozen_string_literal: true

require 'benchmark/ips'
require_relative '../lib/predictability_engine'

# Use a distribution map to generate sample data DRY-ly
distribution = { 0 => 50, 1 => 100, 2 => 70, 3 => 20, 5 => 10 }
throughput_data = distribution.flat_map { |val, count| [val] * count }.shuffle

Benchmark.ips do |x|
  # Total execution time ~18s
  x.config(time: 2, warmup: 1)

  # Dynamic test scenarios using Array#product to minimize repetition
  [10, 400, 1000].product([1000, 10_000]).each do |size, trials|
    x.report("Monte Carlo (#{size} items, #{trials} trials)") do
      PredictabilityEngine::Simulators::MonteCarlo.when_will_it_be_done(size, throughput_data, trials: trials)
    end
  end

  x.compare!
end
