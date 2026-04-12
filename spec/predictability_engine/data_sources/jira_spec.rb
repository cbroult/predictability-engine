# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::DataSources::Jira do
  let(:instance) { described_class.new }

  describe '#first_in_progress_date' do
    let(:issue) { double('Issue') }

    context 'with changelog' do
      let(:changelog) do
        {
          'histories' => [
            {
              'created' => '2024-03-01T10:00:00.000+0000',
              'items' => [{ 'field' => 'status', 'toString' => 'To Do' }]
            },
            {
              'created' => '2024-03-02T10:00:00.000+0000',
              'items' => [{ 'field' => 'status', 'toString' => 'In Progress' }]
            },
            {
              'created' => '2024-03-03T10:00:00.000+0000',
              'items' => [{ 'field' => 'status', 'toString' => 'Done' }]
            }
          ]
        }
      end

      before do
        allow(issue).to receive(:respond_to?).with(:changelog).and_return(true)
        allow(issue).to receive(:changelog).and_return(changelog)
      end

      it 'returns the date of the first transition to "In Progress"' do
        expect(instance.send(:first_in_progress_date, issue)).to eq('2024-03-02T10:00:00.000+0000')
      end
    end

    context 'without matching transition' do
      let(:changelog) do
        {
          'histories' => [
            {
              'created' => '2024-03-01T10:00:00.000+0000',
              'items' => [{ 'field' => 'status', 'toString' => 'To Do' }]
            }
          ]
        }
      end

      before do
        allow(issue).to receive(:respond_to?).with(:changelog).and_return(true)
        allow(issue).to receive(:changelog).and_return(changelog)
      end

      it 'returns nil' do
        expect(instance.send(:first_in_progress_date, issue)).to be_nil
      end
    end

    describe '#validate_issue_contract!' do
      let(:issue) { double('JiraIssue', key: 'PROJ-1', summary: 'Title', created: '2024-01-01', issuetype: double(name: 'Story')) }

      it 'passes for valid issue' do
        expect { instance.send(:validate_issue_contract!, issue) }.not_to raise_error
      end

      it 'raises error for missing summary' do
        allow(issue).to receive(:summary).and_return(nil)
        expect { instance.send(:validate_issue_contract!, issue) }.to raise_error(PredictabilityEngine::Error, /missing 'summary'/)
      end

      it 'raises error for missing issuetype' do
        allow(issue).to receive(:issuetype).and_return(nil)
        expect { instance.send(:validate_issue_contract!, issue) }.to raise_error(PredictabilityEngine::Error, /missing 'issuetype'/)
      end
    end
  end

  describe '#map_issue' do
    let(:issue) do
      double('Issue',
             key: 'PROJ-1',
             summary: 'Test issue',
             issuetype: double('IssueType', name: 'Story'),
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
    it 'raises error when site is missing' do
      allow(PredictabilityEngine::Config).to receive(:jira).and_return({ email: 'test@example.com', token: 'token' })
      expect { instance.send(:build_client) }.to raise_error(PredictabilityEngine::Error, /Jira site not configured/)
    end

    it 'raises error when email is missing' do
      allow(PredictabilityEngine::Config).to receive(:jira).and_return({ site: 'https://jira.com', token: 'token' })
      expect { instance.send(:build_client) }.to raise_error(PredictabilityEngine::Error, /Jira email not configured/)
    end

    it 'raises error when token is missing' do
      allow(PredictabilityEngine::Config).to receive(:jira).and_return({ site: 'https://jira.com', email: 'test@example.com' })
      expect { instance.send(:build_client) }.to raise_error(PredictabilityEngine::Error, /Jira API token not configured/)
    end
  end
end
