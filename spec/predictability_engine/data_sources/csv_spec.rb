# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe PredictabilityEngine::DataSources::Csv do
  def load_csv(content)
    Tempfile.create(['test', '.csv']) do |f|
      f.write(content)
      f.flush
      described_class.new.load(f.path)
    end
  end

  context 'with standard CSV headers' do
    let(:items) do
      load_csv(<<~CSV)
        id,title,type,priority,start_date,end_date
        ITEM-1,Do the thing,Story,High,2026-01-10,2026-01-20
        ITEM-2,Fix the bug,Bug,Medium,2026-02-01,
      CSV
    end

    it 'maps id and title' do
      expect(items[0].id).to eq('ITEM-1')
      expect(items[0].title).to eq('Do the thing')
    end

    it 'maps type and priority' do
      expect(items[0].type).to eq('Story')
      expect(items[0].priority).to eq('High')
    end

    it 'maps start_date and end_date' do
      expect(items[0].start_date).to eq(Date.new(2026, 1, 10))
      expect(items[0].end_date).to eq(Date.new(2026, 1, 20))
    end

    it 'returns nil end_date for blank value' do
      expect(items[1].end_date).to be_nil
    end
  end

  context 'with done_statuses configured' do
    let(:csv_content) do
      <<~CSV
        Issue key,Summary,Issue Type,Priority,Created,Updated,Resolved,Status
        PROJ-1,Done no resolved,Story,High,2026-01-10,2026-01-25,,Done
        PROJ-2,Done with resolved,Story,High,2026-01-10,2026-01-25,2026-01-20,Done
        PROJ-3,In progress,Story,High,2026-01-10,2026-01-25,,In Progress
      CSV
    end

    context 'with a sidecar YAML' do
      let(:items) do
        Dir.mktmpdir do |dir|
          csv_path = File.join(dir, 'issues.csv')
          File.write(csv_path, csv_content)
          File.write(File.join(dir, 'issues.yml'), "done_statuses:\n  - Done\n")
          described_class.new.load(csv_path)
        end
      end

      it 'uses Updated as end_date when Status is done and Resolved is blank' do
        expect(items[0].end_date).to eq(Date.new(2026, 1, 25))
      end

      it 'keeps explicit Resolved date even when Status is done' do
        expect(items[1].end_date).to eq(Date.new(2026, 1, 20))
      end

      it 'returns nil end_date for non-done status with blank Resolved' do
        expect(items[2].end_date).to be_nil
      end
    end

    context 'with .predictability_engine.yml fallback' do
      let(:items) do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            csv_path = File.join(dir, 'issues.csv')
            File.write(csv_path, csv_content)
            File.write('.predictability_engine.yml',
                       "jira_csv:\n  done_statuses:\n    - Done\n")
            described_class.new.load(csv_path)
          end
        end
      end

      it 'uses Updated as end_date when Status is done and Resolved is blank' do
        expect(items[0].end_date).to eq(Date.new(2026, 1, 25))
      end
    end
  end

  context 'with Jira CSV export headers' do
    let(:items) do
      load_csv(<<~CSV)
        Issue key,Summary,Issue Type,Priority,Created,Resolved
        PROJ-1,Do the thing,Story,High,2026-01-10,2026-01-20
        PROJ-2,Fix the bug,Bug,Medium,2026-02-01,
      CSV
    end

    it 'remaps Issue key to id' do
      expect(items[0].id).to eq('PROJ-1')
    end

    it 'remaps Summary to title' do
      expect(items[0].title).to eq('Do the thing')
    end

    it 'remaps Issue Type to type' do
      expect(items[0].type).to eq('Story')
    end

    it 'maps Priority directly' do
      expect(items[0].priority).to eq('High')
    end

    it 'remaps Created to start_date' do
      expect(items[0].start_date).to eq(Date.new(2026, 1, 10))
    end

    it 'remaps Resolved to end_date' do
      expect(items[0].end_date).to eq(Date.new(2026, 1, 20))
    end

    it 'returns nil end_date for blank Resolved' do
      expect(items[1].end_date).to be_nil
    end
  end
end
