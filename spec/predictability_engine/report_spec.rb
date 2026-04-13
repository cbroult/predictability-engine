# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::Report do
  let(:items) do
    [
      PredictabilityEngine::Models::WorkItem.new(
        item_id: 'PROJ-1',
        title: 'Task 1',
        start_date: '2026-03-01',
        end_date: '2026-03-05'
      )
    ]
  end
  let(:report) { described_class.new(items) }

  describe '#render' do
    context 'when terminal format is requested' do
      it 'renders ASCII charts even if images are available' do
        # Mock images_path and File.exist? to simulate available images
        allow(report).to receive(:images_path).and_return('some/path')
        allow(File).to receive(:exist?).and_return(true)

        content = report.render(:terminal)

        expect(content).not_to include('![](images/')
        expect(content).to include('Aging Work In Progress')
      end
    end

    context 'when markdown format is requested' do
      it 'renders image links if images are available' do
        allow(report).to receive(:images_path).and_return('some/path')
        allow(File).to receive(:exist?).with('some/path/aging_wip.png').and_return(true)
        allow(File).to receive(:exist?).with(/.*\.png$/).and_return(true)

        content = report.render(:markdown)

        expect(content).to include('![](images/')
      end

      it 'renders mermaid if no images are available' do
        allow(report).to receive(:images_path).and_return(nil)
        content = report.render(:markdown)
        expect(content).to include('```mermaid')
      end

      it 'renders confluence image links' do
        allow(report).to receive(:images_path).and_return('some/path')
        allow(File).to receive(:exist?).and_return(true)
        content = report.render(:confluence)
        expect(content).to include('!images/')
      end

      it 'renders confluence mermaid' do
        allow(report).to receive(:images_path).and_return(nil)
        content = report.render(:confluence)
        expect(content).to include('{mermaid}')
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
  end

  describe '.generate_all' do
    it 'generates sub-reports by type if multiple types exist' do
      items << PredictabilityEngine::Models::WorkItem.new(item_id: 'PROJ-2', title: 'Task 2', type: 'Bug')
      items[0].instance_variable_set(:@type, 'Story') # Ensure first item has a type
      
      reports = described_class.generate_all(items)
      expect(reports).to have_key('Story')
      expect(reports).to have_key('Bug')
      expect(reports).to have_key(:all)
    end
  end

  describe '#playwright_bin' do
    it 'returns npx playwright if local bin missing' do
      allow(File).to receive(:exist?).and_return(false)
      expect(report.playwright_bin).to eq('npx playwright')
    end
  end
end
