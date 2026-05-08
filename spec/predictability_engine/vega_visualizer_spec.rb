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

  include_context 'with mocked today'

  def find_layer(spec, mark_type)
    spec['layer'].find { |l| l['mark'] && (l['mark'] == mark_type || l['mark']['type'] == mark_type) }
  end

  def all_layer_y_titles(spec)
    (spec['layer'] || []).filter_map { |l| l.dig('encoding', 'y', 'title') }
  end

  describe '.cycle_time_scatter' do
    let(:scatter_spec) { described_class.cycle_time_scatter(items).spec.deep_stringify_keys }
    let(:scatter_points) { find_layer(scatter_spec, 'point') }
    let(:cycle_axis) { scatter_points['encoding']['x']['axis'] }

    it 'uses a consistent y-axis title across all layers' do
      expect(all_layer_y_titles(scatter_spec).uniq).to eq(['Cycle Time (days)'])
    end

    it 'generates a spec with correct percentile line styles' do
      rules_layer = find_layer(scatter_spec, 'rule')

      expect(rules_layer).not_to be_nil
      expect(rules_layer['encoding']['strokeDash']).to have_key('condition')
      expect(rules_layer['encoding']['strokeWidth']).to have_key('condition')

      dash_conditions = rules_layer['encoding']['strokeDash']['condition']
      width_conditions = rules_layer['encoding']['strokeWidth']['condition']

      # Check for 85th percentile as an example of complex dash
      expect(dash_conditions.find { |c| c['test'] == 'datum.p == 85' }['value']).to eq([4, 4])
      expect(width_conditions.find { |c| c['test'] == 'datum.p == 85' }['value']).to eq(2.5)
    end

    it 'includes weekly tick intervals on the x-axis' do
      expect(cycle_axis['tickCount']).to eq({ 'interval' => 'week' })
    end

    it 'includes href encoding on the points layer for URL clickability' do
      expect(scatter_points['encoding']['href']).to eq({ 'field' => 'url', 'type' => 'nominal' })
    end
  end

  describe '.aging_wip' do
    let(:awip_spec) { described_class.aging_wip(items).spec.deep_stringify_keys }
    let(:awip_bar) { find_layer(awip_spec, 'bar') }

    it 'uses a consistent y-axis title across all layers' do
      expect(all_layer_y_titles(awip_spec).uniq).to eq(['Age (days)'])
    end

    it 'includes href encoding on the bar layer for URL clickability' do
      expect(awip_bar['encoding']['href']).to eq({ 'field' => 'url', 'type' => 'nominal' })
    end
  end

  describe '.forecasted_cfd' do
    let(:cfd_spec) { described_class.forecasted_cfd(items).spec.deep_stringify_keys }
    let(:cfd_axis) { cfd_spec['encoding']['x']['axis'] }
    let(:cfd_text_layer) { find_layer(cfd_spec, 'text') }

    it 'uses a consistent y-axis title across all layers' do
      expect(all_layer_y_titles(cfd_spec).uniq).to eq(['Total Items'])
    end

    it 'generates a spec with explicit tick values on x-axis' do
      expect(cfd_axis['values']).not_to be_empty
    end

    it 'includes vertical forecast layers with date-enhanced labels' do
      expect(cfd_text_layer).not_to be_nil
      # We need to find the data in the layer itself or at the top level
      data_values = cfd_text_layer['data'] ? cfd_text_layer['data']['values'] : cfd_spec['data']['values']
      expect(data_values).not_to be_nil

      label_data = data_values.find { |v| v['label']&.include?('%') }
      expect(label_data).not_to be_nil

      # Label should look like "50% (2026-04-17)"
      expect(label_data['label']).to match(/\d+% \(20\d{2}-\d{2}-\d{2}\)/)
    end

    it 'sets clip: false on the text layer mark to prevent label clipping at right edge' do
      expect(cfd_text_layer).not_to be_nil
      expect(cfd_text_layer['mark']['clip']).to be false
    end

    it 'includes right padding in config so clipped labels stay within SVG bounds' do
      expect(cfd_spec.dig('config', 'padding', 'right')).to be > 0
    end
  end

  describe '.cfd' do
    let(:cfd_spec) { described_class.cfd(items).spec.deep_stringify_keys }

    it 'does not expose the order field in area layer tooltips' do
      area = find_layer(cfd_spec, 'area')
      tooltip_fields = area['encoding']['tooltip'].map { |f| f['field'] }
      expect(tooltip_fields).not_to include('order')
      expect(tooltip_fields).to include('date', 'type', 'count')
    end
  end

  describe '.cycle_time_bands' do
    let(:bands_spec) { described_class.cycle_time_bands(items).spec.deep_stringify_keys }
    let(:bands_tooltip) { bands_spec.dig('encoding', 'tooltip') }

    it 'has an explicit tooltip encoding excluding band_order' do
      expect(bands_tooltip).to be_an(Array)
      expect(bands_tooltip.map { |f| f['field'] }.compact).not_to include('band_order')
    end

    it 'includes period, band, and count aggregate in tooltip' do
      expect(bands_tooltip).to include(a_hash_including('field' => 'period'))
      expect(bands_tooltip).to include(a_hash_including('field' => 'band'))
      expect(bands_tooltip).to include(a_hash_including('aggregate' => 'count'))
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
