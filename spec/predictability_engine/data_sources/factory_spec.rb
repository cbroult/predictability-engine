# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::DataSources::Factory do
  describe '.for' do
    [
      ['jira', PredictabilityEngine::DataSources::Jira],
      ['PROJ', PredictabilityEngine::DataSources::Jira],
      ['my_data.csv', PredictabilityEngine::DataSources::Csv],
      ['myProject', PredictabilityEngine::DataSources::Csv]
    ].each do |input, expected_class|
      it "returns #{expected_class.name.split('::').last} for '#{input}'" do
        expect(described_class.for(input)).to be_a(expected_class)
      end
    end
  end
end
