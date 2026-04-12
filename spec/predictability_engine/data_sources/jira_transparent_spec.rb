# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::DataSources::Jira do
  let(:instance) { described_class.new }

  describe '#resolve_source' do
    it "uses JIRA_PROJECT and JIRA_PROFILE when spec is 'jira'" do
      stub_const('ENV', { 'JIRA_PROJECT' => 'PROJ', 'JIRA_PROFILE' => 'client-x' })
      profile, query = instance.send(:resolve_source, 'jira')
      expect(profile).to eq('client-x')
      expect(query).to eq('project = "PROJ"')
    end

    it "treats all-caps strings as project keys" do
      stub_const('ENV', { 'JIRA_PROFILE' => 'env-profile' })
      profile, query = instance.send(:resolve_source, 'MYPROJ')
      expect(profile).to eq('env-profile')
      expect(query).to eq('project = "MYPROJ"')
    end

    it "raises error if 'jira' keyword is used without JIRA_PROJECT env var" do
      stub_const('ENV', {})
      expect { instance.send(:resolve_source, 'jira') }.to raise_error(PredictabilityEngine::Error, /No JIRA project specified/)
    end

    it "uses JIRA_PROJECT_QUERY if provided" do
      stub_const('ENV', { 'JIRA_PROJECT_QUERY' => 'filter = 12345' })
      profile, query = instance.send(:resolve_source, 'jira')
      expect(query).to eq('filter = 12345')
    end
  end
end

RSpec.describe PredictabilityEngine::DataSources::Factory do
  describe '.for' do
    it "returns Jira for 'jira' keyword" do
      expect(described_class.for('jira')).to be_a(PredictabilityEngine::DataSources::Jira)
    end

    it "returns Jira for all-caps strings" do
      expect(described_class.for('PROJ')).to be_a(PredictabilityEngine::DataSources::Jira)
    end

    it "still returns Csv for mixed case or file-like strings" do
      expect(described_class.for('my_data.csv')).to be_a(PredictabilityEngine::DataSources::Csv)
      expect(described_class.for('myProject')).to be_a(PredictabilityEngine::DataSources::Csv)
    end
  end
end
