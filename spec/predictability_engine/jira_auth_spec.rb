# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::JiraAuth do
  describe '.build' do
    {
      nil => PredictabilityEngine::JiraAuth::Basic,
      'basic' => PredictabilityEngine::JiraAuth::Basic,
      'bearer' => PredictabilityEngine::JiraAuth::Bearer,
      'cookie' => PredictabilityEngine::JiraAuth::Cookie,
      'mfa_api' => PredictabilityEngine::JiraAuth::MfaApi,
      'mfa_browser' => PredictabilityEngine::JiraAuth::MfaBrowser
    }.each do |mode, klass|
      it "returns #{klass.name.split('::').last} for auth_mode #{mode.inspect}" do
        expect(described_class.build({ auth_mode: mode })).to be_a(klass)
      end
    end

    it 'raises for unknown auth_mode' do
      expect { described_class.build({ auth_mode: 'unknown' }) }
        .to raise_error(PredictabilityEngine::Error, /Unknown Jira auth_mode/)
    end
  end
end
