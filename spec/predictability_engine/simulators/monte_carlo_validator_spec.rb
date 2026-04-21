# frozen_string_literal: true

require 'spec_helper'
require 'date'

RSpec.describe PredictabilityEngine::Simulators::MonteCarloValidator do
  # 25 completed items, 1 completing per day starting day 1.
  # All start on base; item i ends on base+i → throughput is exactly 1/day.
  # At any as-of date d in [base+10, base+24]:
  #   - completed items: i where end_date <= d  (at least 10)
  #   - in-flight items: i where end_date > d   (at least 1)
  #   - MC predicts exactly (25 - (d-base)) days; actual is the same → 100% coverage
  let(:base) { Date.parse('2025-01-01') }

  def build_dated_items(count, start_offset: 0)
    (1..count).map do |i|
      PredictabilityEngine::Models::WorkItem.new(
        item_id: i,
        start_date: (base + start_offset).to_s,
        end_date: (base + start_offset + i).to_s
      )
    end
  end

  let(:regular_items) { build_dated_items(25) }

  # Items where start == end: completed? is true, but in_progress? is always false.
  let(:never_in_flight_items) do
    (1..25).map do |i|
      PredictabilityEngine::Models::WorkItem.new(item_id: i, start_date: (base + i).to_s, end_date: (base + i).to_s)
    end
  end

  let(:opts) { { validation_trials: 20, primary_trials: 500 } }

  describe '.calibration' do
    context 'with fewer than MIN_COMPLETED_ITEMS completed items' do
      let(:tiny) { build_dated_items(5) }

      it 'returns nil' do
        expect(described_class.calibration(tiny, **opts)).to be_nil
      end
    end

    context 'when no in-flight items exist at any candidate date' do
      it 'returns nil' do
        expect(described_class.calibration(never_in_flight_items, **opts)).to be_nil
      end
    end

    context 'with a regular dataset (1 item/day throughput)' do
      subject(:result) { described_class.calibration(regular_items, **opts) }

      it 'returns a Hash keyed by each percentile and metadata' do
        expect(result).to include(50, 75, 85, 95, 98, :trials_run, :trials_skipped)
      end

      it 'coverage values are between 0.0 and 1.0' do
        PredictabilityEngine::DEFAULT_PERCENTILES.each do |p|
          expect(result[p]).to be_between(0.0, 1.0), "p#{p} coverage #{result[p]} out of range"
        end
      end

      it 'higher percentiles have >= coverage than lower percentiles (monotonicity)' do
        percentiles = PredictabilityEngine::DEFAULT_PERCENTILES
        percentiles.each_cons(2) do |lower, higher|
          expect(result[higher]).to be >= result[lower],
                                    "p#{higher} (#{result[higher]}) < p#{lower} (#{result[lower]})"
        end
      end

      it 'trials_run + trials_skipped equals validation_trials' do
        expect(result[:trials_run] + result[:trials_skipped]).to eq(opts[:validation_trials])
      end

      it 'is deterministic across repeated calls' do
        r1 = described_class.calibration(regular_items, **opts)
        r2 = described_class.calibration(regular_items, **opts)
        expect(r1).to eq(r2)
      end

      it 'p50 coverage exceeds 80% for a perfectly regular process' do
        expect(result[50]).to be > 0.8
      end
    end
  end
end
