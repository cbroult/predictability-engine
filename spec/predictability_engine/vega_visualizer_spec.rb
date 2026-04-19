# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::VegaVisualizer do
  let(:today) { Date.new(2026, 4, 17) }
  let(:items) do
    [
      PredictabilityEngine::Models::WorkItem.new(item_id: 'T1', type: 'Task', title: 'T1', start_date: today - 10,
                                                 end_date: today - 5),
      PredictabilityEngine::Models::WorkItem.new(item_id: 'T2', type: 'Task', title: 'T2', start_date: today - 5,
                                                 end_date: nil)
    ]
  end

  around do |example|
    old_mock_today = ENV.fetch('MOCK_TODAY', nil)
    ENV['MOCK_TODAY'] = today.to_s
    example.run
    ENV['MOCK_TODAY'] = old_mock_today
  end

  describe '.cycle_time_scatter' do
    it 'generates a spec with correct percentile line styles' do
      chart = described_class.cycle_time_scatter(items)
      spec = chart.spec.deep_stringify_keys
      rules_layer = spec['layer'].find { |l| l['mark'] && (l['mark'] == 'rule' || l['mark']['type'] == 'rule') }

      expect(rules_layer).not_to be_nil
      expect(rules_layer['encoding']['strokeDash']).to have_key('condition')
      expect(rules_layer['encoding']['strokeWidth']).to have_key('condition')

      dash_conditions = rules_layer['encoding']['strokeDash']['condition']
      width_conditions = rules_layer['encoding']['strokeWidth']['condition']

      # Check for 85th percentile as an example of complex dash
      expect(dash_conditions.find { |c| c['test'] == 'datum.p == 85' }['value']).to eq([4, 4])
      expect(width_conditions.find { |c| c['test'] == 'datum.p == 85' }['value']).to eq(2.5)
    end

    it 'includes daily markers on the x-axis' do
      chart = described_class.cycle_time_scatter(items)
      spec = chart.spec.deep_stringify_keys
      points_layer = spec['layer'].find { |l| l['mark'] && (l['mark'] == 'point' || l['mark']['type'] == 'point') }
      axis = points_layer['encoding']['x']['axis']

      expect(axis['minorTicks']).to be true
      expect(axis['tickCount']).to eq({ 'interval' => 'week' })
    end
  end

  describe '.forecasted_cfd' do
    it 'generates a spec with daily markers and minor ticks on x-axis' do
      chart = described_class.forecasted_cfd(items)
      spec = chart.spec.deep_stringify_keys
      axis = spec['encoding']['x']['axis']

      expect(axis['minorTicks']).to be true
      expect(axis['minorTickSize']).to eq(4)
      # In base_cfd_chart, tickCount is not explicitly set, but values are provided
      expect(axis['values']).not_to be_empty
    end

    it 'includes vertical forecast layers with date-enhanced labels' do
      chart = described_class.forecasted_cfd(items)
      spec = chart.spec.deep_stringify_keys
      text_layer = spec['layer'].find { |l| l['mark'] && (l['mark'] == 'text' || l['mark']['type'] == 'text') }

      expect(text_layer).not_to be_nil
      # We need to find the data in the layer itself or at the top level
      data_values = text_layer['data'] ? text_layer['data']['values'] : spec['data']['values']
      expect(data_values).not_to be_nil

      label_data = data_values.find { |v| v['label']&.include?('%') }
      expect(label_data).not_to be_nil

      # Label should look like "50% (2026-04-17)"
      expect(label_data['label']).to match(/\d+% \(20\d{2}-\d{2}-\d{2}\)/)
    end
  end

  describe '.dashboard' do
    it 'combines all 5 standard charts' do
      chart = described_class.dashboard(items)
      spec = chart.spec.deep_stringify_keys
      expect(spec['vconcat'].size).to eq(5)
    end
  end
end
