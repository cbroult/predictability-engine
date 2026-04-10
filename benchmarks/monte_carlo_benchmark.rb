# frozen_string_literal: true

require 'benchmark/ips'
require_relative '../lib/predictability_engine'

# Prepare sample data
throughput_data = [1, 2, 0, 1, 3, 2, 1, 0, 1, 2] * 10 # 100 days of data

Benchmark.ips do |x|
  x.report('Monte Carlo (10 items, 1000 trials)') do
    PredictabilityEngine::Simulators::MonteCarlo.when_will_it_be_done(10, throughput_data, trials: 1000)
  end

  x.report('Monte Carlo (50 items, 1000 trials)') do
    PredictabilityEngine::Simulators::MonteCarlo.when_will_it_be_done(50, throughput_data, trials: 1000)
  end

  x.report('Monte Carlo (10 items, 5000 trials)') do
    PredictabilityEngine::Simulators::MonteCarlo.when_will_it_be_done(10, throughput_data, trials: 5000)
  end

  x.compare!
end
