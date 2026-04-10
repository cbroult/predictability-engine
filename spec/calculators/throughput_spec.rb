# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::Calculators::Throughput do
  let(:date1) { Date.new(2026, 4, 1) }
  let(:date2) { Date.new(2026, 4, 2) }
  let(:date3) { Date.new(2026, 4, 3) }

  let(:item1) { instance_double(PredictabilityEngine::Models::WorkItem, completed?: true, end_date: date1) }
  let(:item2) { instance_double(PredictabilityEngine::Models::WorkItem, completed?: true, end_date: date2) }
  let(:item3) { instance_double(PredictabilityEngine::Models::WorkItem, completed?: true, end_date: date2) }
  let(:item4) { instance_double(PredictabilityEngine::Models::WorkItem, completed?: false) }

  describe '.daily' do
    it 'returns counts per completion day' do
      items = [item1, item2, item3, item4]
      daily = described_class.daily(items)
      expect(daily[date1]).to eq(1)
      expect(daily[date2]).to eq(2)
      expect(daily.keys.size).to eq(2)
    end

    it 'fills in zeros for days with no completions if range is provided' do
      items = [item1, item3]
      daily = described_class.daily(items, start_date: date1, end_date: date3)
      expect(daily[date1]).to eq(1)
      expect(daily[date2]).to eq(1)
      expect(daily[date3]).to eq(0)
    end
  end

  describe '.average' do
    it 'calculates average throughput correctly' do
      items = [item1, item2, item3]
      # Day 1: 1 item, Day 2: 2 items. Total 3 items over 2 days.
      expect(described_class.average(items)).to eq(1.5)
    end

    it 'returns 0 if no data' do
      expect(described_class.average([])).to eq(0)
    end
  end
end
