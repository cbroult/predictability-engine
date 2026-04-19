# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

# Load the script under test without running its CLI entry point
module JiraProjectSetup; end
load File.expand_path('../../scripts/jira_project_setup.rb', __dir__)

RSpec.describe JiraProjectSetup do
  describe '.project_key' do
    {
      %w[dev TBD] => 'PEDEVTBD',
      %w[dev TQW] => 'PEDEVTQW',
      %w[dev TST] => 'PEDEVTST',
      %w[wp TBD] => 'PEWPTBD',
      %w[wp TQW] => 'PEWPTQW',
      %w[wp TST] => 'PEWPTST',
      %w[gha TBD] => 'PEGHATBD',
      %w[gha TQW] => 'PEGHATQW',
      %w[gha TST] => 'PEGHATST'
    }.each do |args, expected|
      it "returns #{expected} for env=#{args[0]}, team=#{args[1]}" do
        expect(described_class.project_key(*args)).to eq(expected)
      end
    end

    it 'upcases unknown env codes' do
      expect(described_class.project_key('staging', 'TBD')).to eq('PESTAGINGTBD')
    end
  end

  describe '.load_teams' do
    subject(:teams) { described_class.load_teams }

    it 'loads three teams' do
      expect(teams.size).to eq(3)
    end

    it 'includes TBD, TQW, TST abbreviations' do
      expect(teams.map { |t| t['abbrev'] }).to eq(%w[TBD TQW TST])
    end

    it 'each team has required keys' do
      teams.each do |team|
        expect(team.keys).to include('abbrev', 'name', 'workflow', 'issue_types', 'statuses')
      end
    end

    it 'each team has at least one arrival status' do
      teams.each do |team|
        arrivals = team['statuses'].select { |s| s['role'] == 'arrival' }
        expect(arrivals).not_to be_empty, "#{team['abbrev']} has no arrival status"
      end
    end

    it 'each team has at least one departure status' do
      teams.each do |team|
        departures = team['statuses'].select { |s| s['role'] == 'departure' }
        expect(departures).not_to be_empty, "#{team['abbrev']} has no departure status"
      end
    end
  end

  describe JiraProjectSetup::DataSeeder do
    let(:teams)    { JiraProjectSetup.load_teams }
    let(:tbd_team) { teams.find { |t| t['abbrev'] == 'TBD' } }

    describe '#bucket_for (private)' do
      let(:seeder) { described_class.new(nil, 'PEDEVTBD', tbd_team, count: 10) }

      it 'assigns :completed to the first 60%' do
        (1..6).each { |i| expect(seeder.send(:bucket_for, i)).to eq(:completed) }
      end

      it 'assigns :in_progress to the next 30%' do
        (7..9).each { |i| expect(seeder.send(:bucket_for, i)).to eq(:in_progress) }
      end

      it 'assigns :backlog to the last 10%' do
        expect(seeder.send(:bucket_for, 10)).to eq(:backlog)
      end
    end

    describe 'DISTRIBUTION' do
      it 'sums to 1.0' do
        total = JiraProjectSetup::DataSeeder::DISTRIBUTION.sum { |d| d[:share] }
        expect(total).to be_within(0.001).of(1.0)
      end
    end
  end
end
