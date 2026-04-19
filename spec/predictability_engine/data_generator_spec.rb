# frozen_string_literal: true

require 'csv'
require 'tmpdir'

RSpec.describe PredictabilityEngine::DataGenerator do
  describe '.content' do
    it 'emits the standard four-column header' do
      rows = CSV.parse(described_class.content(size: :small))
      expect(rows.first).to eq(%w[id title start_date end_date])
    end

    it 'honours the preset counts' do
      rows = CSV.parse(described_class.content(size: :small), headers: true)
      small = described_class::PRESETS[:small]
      expect(rows.size).to eq(small[:completed] + small[:wip])
    end

    it 'lets caller override counts' do
      rows = CSV.parse(described_class.content(completed: 3, wip: 2), headers: true)
      expect(rows.size).to eq(5)
    end

    it 'leaves end_date empty for WIP items only' do
      rows = CSV.parse(described_class.content(completed: 4, wip: 2), headers: true)
      completed, wip = rows.partition { |r| r['end_date'] && !r['end_date'].empty? }
      expect(completed.size).to eq(4)
      expect(wip.size).to eq(2)
    end

    it 'honours MOCK_TODAY for deterministic date ranges' do
      original = ENV.fetch('MOCK_TODAY', nil)
      ENV['MOCK_TODAY'] = '2026-04-17'
      rows = CSV.parse(described_class.content(completed: 5, wip: 0), headers: true)
      end_dates = rows.map { |r| Date.parse(r['end_date']) }
      expect(end_dates.max).to be <= Date.parse('2026-04-17')
    ensure
      ENV['MOCK_TODAY'] = original
    end

    it 'raises for an unknown size preset' do
      expect { described_class.content(size: :gargantuan) }.to raise_error(ArgumentError, /Unknown size/)
    end
  end

  describe '.generate' do
    it 'writes the CSV to disk and returns the path' do
      Dir.mktmpdir do |dir|
        out = File.join(dir, 'sample.csv')
        path = described_class.generate(output: out, size: :small)
        expect(path).to eq(out)
        expect(File).to exist(out)
        expect(File.size(out)).to be > 0
      end
    end
  end
end
