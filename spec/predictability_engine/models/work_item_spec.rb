# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::Models::WorkItem do
  describe '#url' do
    it 'defaults to nil when not provided' do
      item = described_class.new(item_id: 'T1')
      expect(item.url).to be_nil
    end

    it 'stores and returns the url when provided' do
      item = described_class.new(item_id: 'T1', url: 'https://jira.example.com/browse/T1')
      expect(item.url).to eq('https://jira.example.com/browse/T1')
    end

    it 'is writable via the accessor' do
      item = described_class.new(item_id: 'T1')
      item.url = 'https://jira.example.com/browse/T1'
      expect(item.url).to eq('https://jira.example.com/browse/T1')
    end
  end
end
