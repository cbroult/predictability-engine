# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::Calculators::Cfd do
  let(:date1) { Date.new(2026, 3, 1) }
  let(:date2) { Date.new(2026, 3, 2) }

  let(:item1) do
    instance_double(PredictabilityEngine::Models::WorkItem,
                    start_date: date1, end_date: date2, completed?: true)
  end
  let(:item2) do
    instance_double(PredictabilityEngine::Models::WorkItem,
                    start_date: date1, end_date: nil, completed?: false)
  end

  describe '.calculate' do
    it 'returns cumulative counts for each day' do
      items = [item1, item2]
      cfd = described_class.calculate(items, start_date: date1, end_date: date2)

      expect(cfd[0]).to include(date: date1, arrived: 2, departed: 0, wip: 2)
      expect(cfd[1]).to include(date: date2, arrived: 2, departed: 1, wip: 1)
    end

    it 'returns empty array if no items' do
      expect(described_class.calculate([])).to eq([])
    end
  end

  describe '.forecast_summary' do
    it 'returns nil if no WIP items' do
      expect(described_class.forecast_summary([item1])).to be_nil
    end

    it 'returns forecast metrics when WIP exists' do
      # Need real MonteCarlo results to be mocked or used
      items = [item1, item2]
      summary = described_class.forecast_summary(items)
      expect(summary).to include(:today, :wip, :total_items, :departed_so_far, :p50, :p85, :p95)
      expect(summary[:wip]).to eq(1)
    end
  end
end
