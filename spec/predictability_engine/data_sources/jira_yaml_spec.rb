# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe PredictabilityEngine::DataSources::JiraYaml do
  subject(:jira_yaml) { described_class.new(file_path) }

  let(:temp_dir) { Dir.mktmpdir }
  let(:file_path) { File.join(temp_dir, filename) }
  let(:filename) { 'test.yml' }
  let(:content) { '' }

  before { File.write(file_path, content) }

  after { FileUtils.remove_entry(temp_dir) }

  it 'properly detects profile and query' do
    {
      profile: [
        ['explicitly set in YAML', "jira_profile: prod-instance\n", 'prod-instance', 'p1.yml'],
        ['convention', '', 'client-x', 'client-x.my-team.yml'],
        ['none', '', nil, 'none.yml']
      ],
      query: [
        ['explicitly set in YAML', "query: 'project = PROJ'\n", 'project = PROJ', 'q1.yml'],
        ['project is specified', "project: 'MYPROJ'\n", 'project = "MYPROJ"', 'q2.yml'],
        ['filter_id is specified', "filter_id: '12345'\n", 'filter = "12345"', 'q3.yml'],
        ['filter_name is specified', "filter_name: 'My Filter'\n", 'filter = "My Filter"', 'q4.yml'],
        ['empty YAML', '', 'filter = "my-team"', 'my-team.yml'],
        ['convention filename with filter', '', 'filter = "my-team"', 'client-x.my-team.yml'],
        ['convention filename with project key', '', '(project = "PEDEVTQW" OR filter = "PEDEVTQW")',
         'client-x.PEDEVTQW.yml']
      ]
    }.each do |method, scenarios|
      scenarios.each do |desc, content_str, expected, file_name|
        path = File.join(temp_dir, file_name)
        File.write(path, content_str)
        expect(described_class.new(path).send(method)).to eq(expected), "failed #{method}: #{desc}"
      end
    end
  end

  describe '#workflow_config_path' do
    it 'returns explicit path from YAML when set' do
      path = File.join(temp_dir, 'myspec.yml')
      File.write(path, "workflow_config: /tmp/my.workflow.yml\n")
      expect(described_class.new(path).workflow_config_path).to eq('/tmp/my.workflow.yml')
    end

    it 'auto-discovers workflow config by middle segment convention' do
      workflow_file = File.join(temp_dir, 'PEDEVTQW.workflow.yml')
      File.write(workflow_file, '')
      spec_path = File.join(temp_dir, 'cbroult-atlassian.PEDEVTQW.yml')
      File.write(spec_path, '')

      jira_yaml = described_class.new(spec_path)
      allow(jira_yaml).to receive(:workflow_config_path).and_call_original
      # Stub File.exist? for the candidate path to use our temp dir
      candidate = File.expand_path('~/.config/jira/PEDEVTQW.workflow.yml')
      original_exist = File.method(:exist?)
      allow(File).to receive(:exist?) { |p| p == candidate ? true : original_exist.call(p) }

      expect(jira_yaml.workflow_config_path).to eq(candidate)
    end

    it 'returns nil when no workflow config exists' do
      path = File.join(temp_dir, 'cbroult-atlassian.NOPROJ.yml')
      File.write(path, '')
      expect(described_class.new(path).workflow_config_path).to be_nil
    end
  end
end
