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

  def row_hash(item)
    described_class::HEADERS.zip(described_class.item_row(item)).to_h
  end

  def threshold_flags(row)
    row.values_at(*described_class::HEADERS.grep(/^Done ≤/))
  end

  describe '.item_row' do
    it 'reports cycle_time and nil age for done items' do
      row = row_hash(done_item)
      expect(row['Cycle Time (days)']).to eq(5)
      expect(row['Current Age (days)']).to be_nil
    end

    it 'reports nil cycle_time and an integer age for WIP items' do
      row = row_hash(wip_item)
      expect(row['Cycle Time (days)']).to be_nil
      expect(row['Current Age (days)']).to be_a(Integer)
    end

    it 'sets threshold flags for done items (ct=5: ≤1→false, ≤7→true, rest→true)' do
      expect(threshold_flags(row_hash(done_item))).to eq([false, true, true, true, true])
    end

    it 'sets all threshold flags to nil for WIP items' do
      expect(threshold_flags(row_hash(wip_item))).to eq([nil, nil, nil, nil, nil])
    end

    it 'labels done items as Done and WIP items as In Progress' do
      expect(row_hash(done_item)['Status']).to eq('Done')
      expect(row_hash(wip_item)['Status']).to  eq('In Progress')
    end

    it 'populates YYYY-Week, YYYY-MM, YYYY from end_date for done items' do
      row = row_hash(done_item)
      expect(row['YYYY-Week']).to eq('2026-W02')
      expect(row['YYYY-MM']).to   eq('2026-01')
      expect(row['YYYY']).to      eq(2026)
    end

    it 'leaves YYYY-Week, YYYY-MM, YYYY nil for WIP items' do
      row = row_hash(wip_item)
      expect(row['YYYY-Week']).to be_nil
      expect(row['YYYY-MM']).to   be_nil
      expect(row['YYYY']).to      be_nil
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
