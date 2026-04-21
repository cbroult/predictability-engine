# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::SummaryVisualizer::Helpers do
  def item(priority: nil, end_date: nil)
    PredictabilityEngine::Models::WorkItem.new(
      item_id: SecureRandom.hex(4),
      priority: priority,
      end_date: end_date
    )
  end

  describe '.shared_metrics' do
    let(:completed) { [item(priority: 'High', end_date: '2024-01-05'), item(priority: 'Low', end_date: '2024-01-06')] }
    let(:all_items) { completed + [item] }
    let(:metrics) { { completed: completed, tp_avg: 0.5 } }

    it 'includes Priority Breakdown when completed items have priorities' do
      result = described_class.shared_metrics(all_items, metrics)
      expect(result[:'Priority Breakdown']).to include('High 1').and include('Low 1')
    end

    it 'omits Priority Breakdown when no completed item has a priority' do
      no_priority_metrics = { completed: [item(end_date: '2024-01-05')], tp_avg: 0.0 }
      result = described_class.shared_metrics(all_items, no_priority_metrics)
      expect(result).not_to have_key(:'Priority Breakdown')
    end
  end

  describe 'priority ordering' do
    let(:metrics) do
      completed = [
        item(priority: 'Low', end_date: '2024-01-01'),
        item(priority: 'Highest', end_date: '2024-01-02'),
        item(priority: 'High', end_date: '2024-01-03'),
        item(priority: 'Medium', end_date: '2024-01-04'),
        item(priority: 'Lowest', end_date: '2024-01-05')
      ]
      { completed: completed, tp_avg: 1.0 }
    end

    it 'outputs priorities in standard Jira order' do
      result = described_class.shared_metrics([], metrics)
      breakdown = result[:'Priority Breakdown']
      expect(breakdown.index('Highest')).to be < breakdown.index('High 1')
      expect(breakdown.index('High 1')).to be < breakdown.index('Medium')
      expect(breakdown.index('Medium')).to be < breakdown.index('Low 1')
      expect(breakdown.index('Low 1')).to be < breakdown.index('Lowest')
    end
  end
end
