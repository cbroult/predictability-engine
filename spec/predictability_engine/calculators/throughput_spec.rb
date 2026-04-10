# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::Calculators::Throughput do
  let(:day_one) { Date.new(2026, 4, 1) }
  let(:day_two) { Date.new(2026, 4, 2) }
  let(:day_three) { Date.new(2026, 4, 3) }

  let(:item_on_day_one) { instance_double(PredictabilityEngine::Models::WorkItem, completed?: true, end_date: day_one) }
  let(:first_item_on_day_two) { instance_double(PredictabilityEngine::Models::WorkItem, completed?: true, end_date: day_two) }
  let(:second_item_on_day_two) { instance_double(PredictabilityEngine::Models::WorkItem, completed?: true, end_date: day_two) }
  let(:incomplete_item) { instance_double(PredictabilityEngine::Models::WorkItem, completed?: false) }

  describe '.daily' do
    it 'returns counts per completion day' do
      items = [item_on_day_one, first_item_on_day_two, second_item_on_day_two, incomplete_item]
      daily = described_class.daily(items)
      expect(daily[day_one]).to eq(1)
      expect(daily[day_two]).to eq(2)
      expect(daily.keys.size).to eq(2)
    end

    it 'fills in zeros for days with no completions if range is provided' do
      items = [item_on_day_one, second_item_on_day_two]
      daily = described_class.daily(items, start_date: day_one, end_date: day_three)
      expect(daily[day_one]).to eq(1)
      expect(daily[day_two]).to eq(1)
      expect(daily[day_three]).to eq(0)
    end
  end

  describe '.average' do
    it 'calculates average throughput correctly' do
      items = [item_on_day_one, first_item_on_day_two, second_item_on_day_two]
      # Day 1: 1 item, Day 2: 2 items. Total 3 items over 2 days.
      expect(described_class.average(items)).to eq(1.5)
    end

    it 'returns 0 if no data' do
      expect(described_class.average([])).to eq(0)
    end
  end
end
