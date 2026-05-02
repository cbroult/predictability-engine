# frozen_string_literal: true

require 'spec_helper'
require 'csv'

RSpec.describe PredictabilityEngine::RawDataExporter do
  let(:done_item) do
    PredictabilityEngine::Models::WorkItem.new(item_id: 'D1', title: 'Done task',
                                               start_date: '2026-01-01', end_date: '2026-01-05')
  end
  let(:wip_item) do
    PredictabilityEngine::Models::WorkItem.new(item_id: 'W1', title: 'WIP task',
                                               start_date: '2026-01-01', end_date: nil)
  end

  describe '.item_row' do
    it 'reports cycle_time and nil age for done items' do
      row = described_class.item_row(done_item)
      expect(row[7]).to eq(5)
      expect(row[8]).to be_nil
    end

    it 'reports nil cycle_time and an integer age for WIP items' do
      row = described_class.item_row(wip_item)
      expect(row[7]).to be_nil
      expect(row[8]).to be_a(Integer)
    end

    it 'sets threshold flags for done items (ct=5: ≤1→false, ≤7→true, rest→true)' do
      row = described_class.item_row(done_item)
      expect(row[9..13]).to eq([false, true, true, true, true])
    end

    it 'sets all threshold flags to nil for WIP items' do
      row = described_class.item_row(wip_item)
      expect(row[9..13]).to eq([nil, nil, nil, nil, nil])
    end

    it 'labels done items as Done and WIP items as In Progress' do
      expect(described_class.item_row(done_item)[6]).to eq('Done')
      expect(described_class.item_row(wip_item)[6]).to  eq('In Progress')
    end
  end

  describe '.generate_csv' do
    it 'produces a CSV string with a header row and one row per item' do
      csv  = described_class.generate_csv([done_item, wip_item])
      rows = CSV.parse(csv)
      expect(rows.first).to eq(described_class::HEADERS)
      expect(rows.size).to eq(3)
    end
  end
end
