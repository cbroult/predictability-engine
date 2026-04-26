# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::JiraAuth do
  describe '.build' do
    it 'returns Basic strategy for empty auth_mode' do
      expect(described_class.build({ auth_mode: nil })).to be_a(PredictabilityEngine::JiraAuth::Basic)
    end

    it 'returns Basic strategy for auth_mode: basic' do
      expect(described_class.build({ auth_mode: 'basic' })).to be_a(PredictabilityEngine::JiraAuth::Basic)
    end

    it 'returns Bearer strategy for auth_mode: bearer' do
      expect(described_class.build({ auth_mode: 'bearer' })).to be_a(PredictabilityEngine::JiraAuth::Bearer)
    end

    it 'returns Cookie strategy for auth_mode: cookie' do
      expect(described_class.build({ auth_mode: 'cookie' })).to be_a(PredictabilityEngine::JiraAuth::Cookie)
    end

    it 'returns MfaApi strategy for auth_mode: mfa_api' do
      expect(described_class.build({ auth_mode: 'mfa_api' })).to be_a(PredictabilityEngine::JiraAuth::MfaApi)
    end

    it 'returns MfaBrowser strategy for auth_mode: mfa_browser' do
      expect(described_class.build({ auth_mode: 'mfa_browser' })).to be_a(PredictabilityEngine::JiraAuth::MfaBrowser)
    end

    it 'raises for unknown auth_mode' do
      expect { described_class.build({ auth_mode: 'unknown' }) }
        .to raise_error(PredictabilityEngine::Error, /Unknown Jira auth_mode/)
    end
  end
end
