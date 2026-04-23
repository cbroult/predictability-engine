# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::Report do
  include_context 'with sample work items'

  let(:report) { described_class.new(items) }

  describe '#render' do
    context 'when images are available' do
      before do
        allow(report).to receive(:images_path).and_return('some/path')
        allow(File).to receive(:exist?).and_return(true)
      end

      it 'renders ASCII charts for terminal even when images exist' do
        content = report.render(:terminal)
        expect(content).not_to include('![](images/')
        expect(content).to include('Aging Work In Progress')
      end

      it 'renders image links for markdown' do
        expect(report.render(:markdown)).to include('![](images/')
      end

      it 'renders confluence image links' do
        expect(report.render(:confluence)).to include('!images/')
      end
    end

    context 'when no images are available' do
      before { allow(report).to receive(:images_path).and_return(nil) }

      it 'renders mermaid for markdown' do
        expect(report.render(:markdown)).to include('```mermaid')
      end

      it 'renders confluence mermaid' do
        expect(report.render(:confluence)).to include('{mermaid}')
      end
    end

    describe 'landscape layout' do
      it 'renders markdown landscape' do
        content = report.render(:markdown, layout: :landscape)
        expect(content).to include('| | | |')
        expect(content).to include('| :--- | :--- | :--- |')
      end

      it 'renders confluence landscape' do
        content = report.render(:confluence, layout: :landscape)
        expect(content).to include('h1. Predictability Report')
        expect(content).to include('| *Flow Metrics Summary*')
      end
    end

    describe 'PPT rendering' do
      it 'falls back to multi-slide if screenshot fails' do
        allow(report).to receive(:capture_screenshot).and_raise(StandardError, 'No Playwright')
        # Stub the multi-slide renderer to avoid requiring powerpoint gem in unit tests if not needed,
        # but it is already in Gemfile so it should be fine.
        allow(report).to receive(:render_ppt_multi_slide).and_return('fake_ppt_content')

        expect(report.render(:ppt)).to eq('fake_ppt_content')
      end
    end

    describe 'PDF rendering' do
      it 'falls back to Prawn if Playwright fails' do
        allow(report).to receive(:render_pdf_playwright).and_raise(StandardError, 'No Playwright')
        allow(report).to receive(:render_pdf_prawn).and_return('fake_pdf_content')

        expect(report.render(:pdf)).to eq('fake_pdf_content')
      end

      it 'uses high_fidelity: false to force Prawn' do
        allow(report).to receive(:render_pdf_prawn).and_return('fake_pdf_content')
        expect(report.render(:pdf, high_fidelity: false)).to eq('fake_pdf_content')
      end
    end
  end

  describe '.generate_all' do
    let(:story) do
      build_item('S1', '2024-01-01', '2024-01-05').tap do |i|
        i.instance_variable_set(:@type, 'Story')
        i.instance_variable_set(:@priority, 'High')
      end
    end
    let(:bug) do
      build_item('B1', '2024-01-02', '2024-01-08').tap do |i|
        i.instance_variable_set(:@type, 'Bug')
        i.instance_variable_set(:@priority, 'Low')
      end
    end

    it 'generates sub-reports grouped by facet when multiple values exist' do
      reports = described_class.generate_all([story, bug])
      expect(reports).to have_key(:all)
      expect(reports[:type].keys).to contain_exactly('Story', 'Bug')
      expect(reports[:priority].keys).to contain_exactly('High', 'Low')
    end

    it 'omits a facet whose values are all identical' do
      no_prio_story = build_item('S1', '2024-01-01', '2024-01-05').tap { |i| i.instance_variable_set(:@type, 'Story') }
      no_prio_bug   = build_item('B1', '2024-01-02', '2024-01-08').tap { |i| i.instance_variable_set(:@type, 'Bug') }
      expect(described_class.generate_all([no_prio_story, no_prio_bug])).not_to have_key(:priority)
    end
  end

  describe '#playwright_bin' do
    it 'returns npx playwright if local bin missing' do
      allow(File).to receive(:exist?).and_return(false)
      expect(report.playwright_bin).to eq('npx playwright')
    end
  end
end
