# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe PredictabilityEngine::DataSources::JiraYaml do
  let(:temp_dir) { Dir.mktmpdir }
  let(:file_path) { File.join(temp_dir, filename) }
  let(:filename) { 'test.yml' }
  subject { described_class.new(file_path) }

  after { FileUtils.remove_entry(temp_dir) }

  describe '#profile' do
    context 'when explicitly set in YAML' do
      before { File.write(file_path, "jira_profile: prod-instance\n") }
      it { expect(subject.profile).to eq('prod-instance') }
    end

    context 'when convention profile-name.filter-name.yml is used' do
      let(:filename) { 'client-x.my-team.yml' }
      before { File.write(file_path, "") }
      it { expect(subject.profile).to eq('client-x') }
    end

    context 'when no profile is specified or found by convention' do
      before { File.write(file_path, "") }
      it { expect(subject.profile).to be_nil }
    end
  end

  describe '#query' do
    context 'when explicitly set in YAML' do
      before { File.write(file_path, "query: 'project = PROJ'\n") }
      it { expect(subject.query).to eq('project = PROJ') }
    end

    context 'when project is specified' do
      before { File.write(file_path, "project: 'MYPROJ'\n") }
      it { expect(subject.query).to eq('project = "MYPROJ"') }
    end

    context 'when filter_id is specified' do
      before { File.write(file_path, "filter_id: '12345'\n") }
      it { expect(subject.query).to eq('filter = "12345"') }
    end

    context 'when filter_name is specified' do
      before { File.write(file_path, "filter_name: 'My Filter'\n") }
      it { expect(subject.query).to eq('filter = "My Filter"') }
    end

    context 'when empty YAML and simple filename' do
      let(:filename) { 'my-team.yml' }
      before { File.write(file_path, "") }
      it { expect(subject.query).to eq('filter = "my-team"') }
    end

    context 'when convention profile-name.filter-name.yml is used' do
      let(:filename) { 'client-x.my-team.yml' }
      before { File.write(file_path, "") }
      it { expect(subject.query).to eq('filter = "my-team"') }
    end
  end
end
