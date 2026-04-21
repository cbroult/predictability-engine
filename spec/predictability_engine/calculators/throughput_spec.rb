# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::Calculators::Throughput do
  include_context 'with sample work items'

  let(:day_one) { Date.new(2026, 4, 1) }
  let(:day_two) { Date.new(2026, 4, 2) }
  let(:day_three) { Date.new(2026, 4, 3) }

  let(:item_on_day_one) { mock_item(end_date: day_one) }
  let(:first_item_on_day_two) { mock_item(end_date: day_two) }
  let(:second_item_on_day_two) { mock_item(end_date: day_two) }
  let(:incomplete_item) { mock_item(completed: false) }

  describe '.daily' do
    let(:all_items) { [item_on_day_one, first_item_on_day_two, second_item_on_day_two, incomplete_item] }

    it 'returns counts per completion day' do
      counts = described_class.daily(all_items)
      expect(counts).to include(day_two => 2, day_one => 1)
      expect(counts.keys.size).to eq(2)
    end

    it 'fills in zeros for days with no completions if range is provided' do
      counts = described_class.daily([item_on_day_one, second_item_on_day_two],
                                     start_date: day_one, end_date: day_three)
      expect(counts).to include(day_one => 1, day_two => 1, day_three => 0)
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
