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
      let(:items) { [create_item(1, -10, -5), create_item(2, -2)] }

      it 'aligns vertical lines with forecast curves' do
        data = described_class.forecast_series(items, percentiles: [50])
        expect(data).not_to be_nil
        verify_deadline(data, 50)
      end
    end

    context 'with data ending in the past' do
      let(:items) { [create_item(1, -20, -15), create_item(2, -10)] }

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
      let(:items) { [create_item(1, -10, -5), create_item(2, -2, 10), create_item(3, -2)] }

      it 'aligns the forecast based on the maximum of simulation and scheduled dates' do
        data = described_class.forecast_series(items, percentiles: [50])
        expect(data[:summary][:p50]).to be >= 10
        verify_deadline(data, 50)
      end
    end
  end

  def verify_deadline(data, percentile)
    hist_size = data[:departed].size
    deadline_idx = hist_size - 1 + data[:summary][:"p#{percentile}"]
    expect(data[:forecasts][percentile][deadline_idx]).to eq(data[:summary][:total_items])
  end

  def create_item(item_id, start_offset, end_offset = nil)
    PredictabilityEngine::Models::WorkItem.new(
      item_id: item_id,
      start_date: today + start_offset,
      end_date: end_offset ? today + end_offset : nil
    )
  end
end
