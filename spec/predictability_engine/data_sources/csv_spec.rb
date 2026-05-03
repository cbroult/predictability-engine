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

    let(:workflow_yaml) do
      <<~YAML
        statuses:
          - name: Done
            category: done
            role: departure
          - name: In Progress
            category: in progress
            role: arrival
      YAML
    end

    def load_with_sidecar(sidecar_yaml)
      Dir.mktmpdir do |dir|
        csv_path = File.join(dir, 'issues.csv')
        File.write(csv_path, csv_content)
        File.write(File.join(dir, 'issues.yml'), sidecar_yaml)
        described_class.new.load(csv_path)
      end
    end

    context 'with a sidecar YAML' do
      let(:items) { load_with_sidecar("done_statuses:\n  - Done\n") }

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
            File.write(File.join(dir, 'issues.csv'), csv_content)
            File.write('.predictability_engine.yml',
                       "jira_csv:\n  done_statuses:\n    - Done\n")
            described_class.new.load(File.join(dir, 'issues.csv'))
          end
        end
      end

      it 'picks up done_statuses from project config' do
        expect(items[0].end_date).to eq(Date.new(2026, 1, 25))
      end
    end

    shared_examples 'departure statuses mark items done' do
      it 'treats departure-role statuses as done, non-departure as not done' do
        expect(items[0].end_date).to eq(Date.new(2026, 1, 25))
        expect(items[2].end_date).to be_nil
      end
    end

    context 'with statuses: in workflow format in sidecar' do
      let(:items) { load_with_sidecar(workflow_yaml) }

      it_behaves_like 'departure statuses mark items done'
    end

    context 'with workflow_config_path: pointing to a workflow file' do
      let(:items) do
        Dir.mktmpdir do |dir|
          wf_path = File.join(dir, 'workflow.yml')
          csv_path = File.join(dir, 'issues.csv')
          File.write(wf_path, workflow_yaml)
          File.write(csv_path, csv_content)
          File.write(File.join(dir, 'issues.yml'), "workflow_config_path: #{wf_path}\n")
          described_class.new.load(csv_path)
        end
      end

      it_behaves_like 'departure statuses mark items done'
    end
  end

  context 'with Jira CSV export headers' do
    let(:items) do
      load_csv(<<~CSV)
        Issue key,Summary,Issue Type,Priority,Created,Resolved
        KEY-42,Implement login,Epic,Critical,2025-03-01,2025-03-14
        KEY-43,Write the tests,Task,Low,2025-04-01,
      CSV
    end

    it 'remaps Jira export headers to model fields' do
      expect(items[0].id).to eq('KEY-42')
      expect(items[0].title).to eq('Implement login')
      expect(items[0].type).to eq('Epic')
      expect(items[0].priority).to eq('Critical')
      expect(items[0].start_date).to eq(Date.new(2025, 3, 1))
      expect(items[0].end_date).to eq(Date.new(2025, 3, 14))
      expect(items[1].end_date).to be_nil
    end
  end
end
