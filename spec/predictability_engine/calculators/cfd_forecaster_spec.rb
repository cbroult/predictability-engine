# frozen_string_literal: true

require 'spec_helper'
require 'date'

RSpec.describe PredictabilityEngine::Calculators::CfdForecaster do
  let(:today) { Date.parse('2026-04-11') }

  before do
    allow(Date).to receive(:today).and_return(today)
  end

  describe '.forecast_series' do
    context 'with standard data' do
      let(:items) do
        [
          PredictabilityEngine::Models::WorkItem.new(item_id: 1, start_date: today - 10, end_date: today - 5),
          PredictabilityEngine::Models::WorkItem.new(item_id: 2, start_date: today - 2, end_date: nil)
        ]
      end

      it 'aligns vertical lines with forecast curves' do
        data = described_class.forecast_series(items, percentiles: [50])
        expect(data).not_to be_nil

        hist_size = data[:departed].size
        p50_days = data[:summary][:p50]
        deadline_index = hist_size - 1 + p50_days

        deadline_val = data[:forecasts][50][deadline_index]
        total_items = data[:summary][:total_items]

        expect(deadline_val).to eq(total_items),
                                "Expected #{total_items} items at index #{deadline_index}, got #{deadline_val}"
      end
    end

    context 'with data ending in the past' do
      let(:items) do
        [
          PredictabilityEngine::Models::WorkItem.new(item_id: 1, start_date: today - 20, end_date: today - 15),
          PredictabilityEngine::Models::WorkItem.new(item_id: 2, start_date: today - 10, end_date: nil)
        ]
      end

      it 'correctly synchronizes history up to today before forecasting' do
        data = described_class.forecast_series(items, percentiles: [85])
        expect(data[:dates].include?(today)).to be true

        # Today index
        today_idx = data[:dates].index(today)
        expect(data[:departed][today_idx]).to eq(1) # Item 1
        expect(data[:arrivals][today_idx]).to eq(2) # Items 1 and 2
      end
    end

    context 'with future-scheduled items' do
      let(:items) do
        [
          PredictabilityEngine::Models::WorkItem.new(item_id: 1, start_date: today - 10, end_date: today - 5),
          PredictabilityEngine::Models::WorkItem.new(item_id: 2, start_date: today - 2, end_date: today + 10),
          PredictabilityEngine::Models::WorkItem.new(item_id: 3, start_date: today - 2, end_date: nil)
        ]
      end

      it 'aligns the forecast based on the maximum of simulation and scheduled dates' do
        data = described_class.forecast_series(items, percentiles: [50])
        p50_days = data[:summary][:p50]
        # Item 2 is scheduled for +10 days. If simulation says <10, p50 should be 10.
        expect(p50_days).to be >= 10

        hist_size = data[:departed].size
        deadline_index = hist_size - 1 + p50_days
        deadline_val = data[:forecasts][50][deadline_index]
        total_items = data[:summary][:total_items]

        expect(deadline_val).to eq(total_items)
      end
    end
  end
end
