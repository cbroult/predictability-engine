# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::Calculators::CycleTime do
  let(:item1) { instance_double(PredictabilityEngine::Models::WorkItem, completed?: true, cycle_time: 5) }
  let(:item2) { instance_double(PredictabilityEngine::Models::WorkItem, completed?: true, cycle_time: 10) }
  let(:item3) { instance_double(PredictabilityEngine::Models::WorkItem, completed?: false) }

  describe '.distribution' do
    it 'returns sorted cycle times of completed items' do
      items = [item2, item1, item3]
      expect(described_class.distribution(items)).to eq([5, 10])
    end

    it 'returns empty array if no completed items' do
      expect(described_class.distribution([item3])).to eq([])
    end
  end

  describe '.percentile' do
    let(:items) do
      [5, 5, 10, 10, 15, 20].map do |ct|
        instance_double(PredictabilityEngine::Models::WorkItem, completed?: true, cycle_time: ct)
      end
    end

    it 'calculates the correct percentile (p50)' do
      expect(described_class.percentile(items, 50)).to eq(10)
    end

    it 'calculates the correct percentile (p85)' do
      expect(described_class.percentile(items, 85)).to eq(20)
    end

    it 'returns nil if no completed items' do
      expect(described_class.percentile([item3], 50)).to be_nil
    end
  end
end
