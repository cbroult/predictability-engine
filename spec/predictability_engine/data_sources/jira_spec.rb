# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::DataSources::Jira do
  let(:instance) { described_class.new }

  describe '#first_in_progress_date' do
    let(:issue) { instance_double(JiraMocks::Issue) }
    let(:changelog) { { 'histories' => histories } }

    before { setup_changelog(issue, changelog) }

    context 'with changelog' do
      let(:histories) { [transition('2024-03-01', 'To Do'), transition('2024-03-02', 'In Progress')] }

      it 'returns the date of the first transition to "In Progress"' do
        expect(instance.send(:first_in_progress_date, issue)).to eq('2024-03-02')
      end
    end

    context 'without matching transition' do
      let(:histories) { [transition('2024-03-01', 'To Do')] }

      it 'returns nil' do
        expect(instance.send(:first_in_progress_date, issue)).to be_nil
      end
    end
  end

  describe '#validate_issue_contract!' do
    it 'detects contract violations' do
      [
        [:summary, nil, /missing 'summary'/],
        [:issuetype, nil, /missing 'issuetype'/]
      ].each do |method, val, msg|
        issue = valid_issue_double
        setup_changelog(issue, { histories: [] })
        allow(issue).to receive(method).and_return(val)
        expect_contract_error(issue, msg)
      end
    end
  end

  describe '#map_issue' do
    let(:issue) do
      instance_double(JiraMocks::Issue,
                      key: 'PROJ-1',
                      summary: 'Test issue',
                      issuetype: instance_double(JiraMocks::Issuetype, name: 'Story'),
                      created: '2024-01-01',
                      resolutiondate: '2024-01-10')
    end

    before do
      allow(issue).to receive(:respond_to?).with(:changelog).and_return(false)
    end

    it 'maps issue fields correctly' do
      result = instance.send(:map_issue, issue)
      expect(result[:id]).to eq('PROJ-1')
      expect(result[:title]).to eq('Test issue')
      expect(result[:type]).to eq('Story')
      expect(result[:start_date]).to eq(Date.parse('2024-01-01'))
      expect(result[:end_date]).to eq(Date.parse('2024-01-10'))
    end
  end

  describe '#build_client' do
    it 'raises error when configuration is incomplete' do
      [
        [{ email: 'e', token: 't' }, /Jira Site not configured/],
        [{ site: 's', token: 't' }, /Jira Email not configured/],
        [{ site: 's', email: 'e' }, /Jira Token not configured/]
      ].each do |config, expectation|
        allow(PredictabilityEngine::Config).to receive(:jira).and_return(config)
        expect { instance.send(:build_client) }.to raise_error(PredictabilityEngine::Error, expectation)
      end
    end
  end

  describe '#resolve_source' do
    it "uses JIRA_PROJECT and JIRA_PROFILE when spec is 'jira'" do
      stub_const('ENV', { 'JIRA_PROJECT' => 'PROJ', 'JIRA_PROFILE' => 'client-x' })
      profile, query = instance.send(:resolve_source, 'jira')
      expect(profile).to eq('client-x')
      expect(query).to eq('project = "PROJ"')
    end

    it 'treats all-caps strings as project keys' do
      stub_const('ENV', { 'JIRA_PROFILE' => 'env-profile' })
      profile, query = instance.send(:resolve_source, 'MYPROJ')
      expect(profile).to eq('env-profile')
      expect(query).to eq('project = "MYPROJ"')
    end

    it "raises error if 'jira' keyword is used without JIRA_PROJECT env var" do
      stub_const('ENV', {})
      expect do
        instance.send(:resolve_source, 'jira')
      end.to raise_error(PredictabilityEngine::Error, /No JIRA project specified/)
    end

    it 'uses JIRA_PROJECT_QUERY if provided' do
      stub_const('ENV', { 'JIRA_PROJECT_QUERY' => 'filter = 12345' })
      _, query = instance.send(:resolve_source, 'jira')
      expect(query).to eq('filter = 12345')
    end
  end

  def setup_changelog(issue, changelog)
    allow(issue).to receive(:respond_to?).with(:changelog).and_return(true)
    allow(issue).to receive(:changelog).and_return(changelog)
  end

  def transition(date, status)
    { 'created' => date, 'items' => [{ 'field' => 'status', 'toString' => status }] }
  end

  def valid_issue_double
    itype = instance_double(JiraMocks::Issuetype, name: 'Story')
    instance_double(JiraMocks::Issue, key: 'PROJ-1', summary: 'Title', created: '2024-01-01', issuetype: itype)
  end

  def expect_contract_error(issue, message)
    expect { instance.send(:validate_issue_contract!, issue) }.to raise_error(PredictabilityEngine::Error, message)
  end
end
