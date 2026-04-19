# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe PredictabilityEngine::JiraWorkflow do
  let(:statuses) do
    [
      { 'name' => 'Backlog', 'category' => 'to do', 'role' => nil },
      { 'name' => 'In Progress', 'category' => 'in progress', 'role' => 'arrival' },
      { 'name' => 'Done', 'category' => 'done', 'role' => 'departure' }
    ]
  end
  let(:workflow) { described_class.new(profile: 'acme', project: 'ACME', statuses: statuses) }

  describe '.default_path' do
    it 'returns ~/.config/jira/<profile>.workflow.yml' do
      expect(described_class.default_path('acme')).to eq(File.expand_path('~/.config/jira/acme.workflow.yml'))
    end
  end

  describe '#arrival_names / #departure_names' do
    it 'returns only statuses whose role matches' do
      expect_arrival_and_departure(workflow, arrival: ['In Progress'], departure: ['Done'])
    end
  end

  describe 'load/write round-trip' do
    it 'writes a YAML file and reloads equivalent statuses' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'acme.workflow.yml')
        workflow.write(path)
        reloaded = described_class.load(path)
        expect(reloaded.profile).to eq('acme')
        expect(reloaded.project).to eq('ACME')
        expect_arrival_and_departure(reloaded, arrival: ['In Progress'], departure: ['Done'])
      end
    end

    it 'returns nil when the path does not exist' do
      expect(described_class.load('/nonexistent/path.yml')).to be_nil
    end
  end

  describe '.merge' do
    let(:cfg_a) do
      described_class.new(statuses: [
                            { 'name' => 'In Progress', 'role' => 'arrival', 'category' => 'in progress' },
                            { 'name' => 'Shared', 'role' => 'arrival', 'category' => 'in progress' }
                          ])
    end
    let(:cfg_b) do
      described_class.new(statuses: [
                            { 'name' => 'Review', 'role' => 'arrival', 'category' => 'in progress' },
                            { 'name' => 'Shared', 'role' => 'departure', 'category' => 'done' }
                          ])
    end

    it 'unions statuses, first-assigned role wins on conflict' do
      allow(PredictabilityEngine.logger).to receive(:warn)
      merged = described_class.merge([cfg_a, cfg_b])
      expect(merged.statuses.map { |s| s[:name] }).to contain_exactly('In Progress', 'Review', 'Shared')
      shared = merged.statuses.find { |s| s[:name] == 'Shared' }
      expect(shared[:role]).to eq('arrival')
    end

    it 'logs a warning on role conflict' do
      expect(PredictabilityEngine.logger).to receive(:warn) do |_, &block|
        expect(block.call).to match(/Shared.*arrival vs departure/)
      end
      described_class.merge([cfg_a, cfg_b])
    end
  end

  describe '#refresh' do
    it 'preserves user-edited roles and drops removed statuses' do
      fresh = described_class.new(statuses: [
                                    { 'name' => 'In Progress', 'category' => 'in progress', 'role' => 'arrival' },
                                    { 'name' => 'In Review', 'category' => 'in progress', 'role' => 'arrival' }
                                  ])
      existing = described_class.new(profile: 'acme', project: 'ACME', statuses: [
                                       { 'name' => 'In Progress', 'category' => 'in progress', 'role' => nil },
                                       { 'name' => 'Backlog', 'category' => 'to do', 'role' => nil }
                                     ])

      existing.refresh(fresh)

      names = existing.statuses.map { |s| s[:name] }
      expect(names).to contain_exactly('In Progress', 'In Review')
      ip = existing.statuses.find { |s| s[:name] == 'In Progress' }
      expect(ip[:role]).to be_nil # user had nilled it; refresh must NOT re-apply default
      new_status = existing.statuses.find { |s| s[:name] == 'In Review' }
      expect(new_status[:role]).to eq('arrival') # seeded from fresh default
    end
  end

  describe '.extract' do
    let(:status_struct) { Struct.new(:name, :statusCategory) } # rubocop:disable Naming/MethodName
    let(:jira_statuses) do
      [
        status_struct.new('In Progress', { 'name' => 'In Progress' }),
        status_struct.new('Done', { 'name' => 'Done' }),
        status_struct.new('Backlog', { 'name' => 'To Do' })
      ]
    end

    it 'seeds arrival/departure roles from status category' do
      client = stub_jira_client(jira_statuses)
      allow(PredictabilityEngine::Config).to receive(:jira).with('acme').and_return(project: 'ACME')

      extracted = described_class.extract('acme', client: client)

      expect(extracted.project).to eq('ACME')
      expect_arrival_and_departure(extracted, arrival: ['In Progress'], departure: ['Done'])
    end
  end

  def stub_jira_client(statuses)
    client = double('JiraClient') # rubocop:disable RSpec/VerifiedDoubles
    resource = double('StatusResource', all: statuses) # rubocop:disable RSpec/VerifiedDoubles
    allow(client).to receive(:Status).and_return(resource)
    client
  end

  def expect_arrival_and_departure(workflow, arrival:, departure:)
    expect(workflow.arrival_names).to eq(arrival)
    expect(workflow.departure_names).to eq(departure)
  end
end
