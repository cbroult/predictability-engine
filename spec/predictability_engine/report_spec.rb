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
    end
  end
end
