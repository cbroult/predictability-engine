# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::ExcelExporter do
  let(:items) do
    [PredictabilityEngine::Models::WorkItem.new(item_id: '1', start_date: '2026-01-01', end_date: '2026-01-10'),
     PredictabilityEngine::Models::WorkItem.new(item_id: '2', start_date: '2026-01-01', end_date: nil)]
  end

  it 'produces valid XLSX binary (ZIP magic bytes)' do
    result = described_class.generate(items)
    expect(result[0, 4]).to eq("PK\x03\x04")
  end
end
