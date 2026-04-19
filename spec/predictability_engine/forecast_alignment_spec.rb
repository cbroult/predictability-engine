# frozen_string_literal: true

# IMMUTABLE: see CLAUDE.md §"Forecast alignment invariant".
# Modifying this file without the `[unlock-alignment]` commit-message token
# violates the project's protection policy.

require 'spec_helper'
require 'date'

RSpec.describe 'Forecast alignment invariant (Y-axis)' do # rubocop:disable RSpec/DescribeClass
  let(:today) { Date.parse('2026-04-10') }

  around do |example|
    old_mock_today = ENV.fetch('MOCK_TODAY', nil)
    ENV['MOCK_TODAY'] = today.to_s
    example.run
    ENV['MOCK_TODAY'] = old_mock_today
  end

  def build_item(item_id, start_date, end_date = nil)
    PredictabilityEngine::Models::WorkItem.new(
      item_id: item_id, title: item_id, type: 'Task',
      start_date: start_date, end_date: end_date
    )
  end

  def extract_rule_values(chart)
    spec = chart.spec.deep_stringify_keys
    rule_layer = spec['layer'].find { |l| l['mark'].is_a?(Hash) && l['mark']['type'] == 'rule' }
    rule_layer['data']['values']
  end

  shared_examples 'rule heights touch the percentile plateau' do
    it 'sets each confidence-rule count to (departed_so_far + wip)' do
      chart = PredictabilityEngine::VegaVisualizer.forecasted_cfd(items, percentiles: [50, 85, 95])
      rules = extract_rule_values(chart)

      forecast = PredictabilityEngine::Calculators::CfdForecaster.forecast_series(
        items, percentiles: [50, 85, 95]
      )
      plateau = forecast[:summary][:departed_so_far] + forecast[:summary][:wip]

      expect(rules).not_to be_empty
      rules.each do |r|
        expect(r['count']).to eq(plateau),
                              "rule #{r['label']} has count=#{r['count']}, expected plateau=#{plateau}"
      end
    end
  end

  context 'with the repro_align fixture (matches features/forecast_alignment.feature)' do
    let(:items) do
      [
        build_item('D1', Date.parse('2026-04-01'), Date.parse('2026-04-02')),
        build_item('D2', Date.parse('2026-04-01'), Date.parse('2026-04-03')),
        build_item('D3', Date.parse('2026-04-01'), Date.parse('2026-04-04')),
        build_item('W1', Date.parse('2026-04-01')),
        build_item('W2', Date.parse('2026-04-01')),
        build_item('W3', Date.parse('2026-04-01')),
        build_item('W4', Date.parse('2026-04-01')),
        build_item('W5', Date.parse('2026-04-01')),
        build_item('F1', Date.parse('2026-04-25'))
      ]
    end

    it_behaves_like 'rule heights touch the percentile plateau'
  end

  context 'when all completed items are in the past (no WIP, no future arrivals)' do
    let(:items) do
      (1..8).map { |i| build_item("C#{i}", today - 15 + i, today - 10 + i) } +
        [build_item('Wa', today - 2), build_item('Wb', today - 1)]
    end

    it_behaves_like 'rule heights touch the percentile plateau'
  end

  context 'with mixed WIP + future arrivals further out than p95' do
    let(:items) do
      [
        build_item('D1', today - 20, today - 10),
        build_item('D2', today - 18, today - 8),
        build_item('D3', today - 15, today - 5),
        build_item('W1', today - 3),
        build_item('W2', today - 1),
        build_item('F1', today + 60)
      ]
    end

    it_behaves_like 'rule heights touch the percentile plateau'
  end
end
