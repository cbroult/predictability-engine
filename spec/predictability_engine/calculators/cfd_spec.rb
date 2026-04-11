# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::Calculators::Cfd do
  include_context 'with sample work items'

  let(:start_date) { Date.new(2026, 3, 1) }
  let(:end_date) { Date.new(2026, 3, 2) }

  let(:completed_item) { mock_item(start_date: start_date, end_date: end_date) }
  let(:wip_item) { mock_item(completed: false, start_date: start_date) }

  describe '.calculate' do
    it 'returns cumulative counts for each day' do
      items = [completed_item, wip_item]
      cfd = described_class.calculate(items, start_date: start_date, end_date: end_date)

      expect(cfd[0]).to include(date: start_date, arrived: 2, departed: 0, wip: 2)
      expect(cfd[1]).to include(date: end_date, arrived: 2, departed: 1, wip: 1)
    end

    it 'returns empty array if no items' do
      expect(described_class.calculate([])).to eq([])
    end
  end

  describe '.forecast_summary' do
    it 'returns nil if no WIP items' do
      expect(described_class.forecast_summary([completed_item])).to be_nil
    end

    it 'returns forecast metrics when WIP exists' do
      # Need real MonteCarlo results to be mocked or used
      items = [completed_item, wip_item]
      summary = described_class.forecast_summary(items)
      expect(summary).to include(:today, :wip, :total_items, :departed_so_far, :p50, :p85, :p95)
      expect(summary[:wip]).to eq(1)
    end
  end
end
