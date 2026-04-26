# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::JiraAuth::Basic do
  subject(:strategy) { described_class.new(config) }

  let(:config) { { email: 'user@example.com', token: 'my-token' } }
  let(:base)   { { site: 'https://jira.example.com', context_path: nil, default_headers: {} } }

  it 'sets username, password, and auth_type' do
    result = strategy.jira_options(base)
    expect(result).to include(
      username: 'user@example.com',
      password: 'my-token',
      auth_type: :basic
    )
  end

  it 'preserves base options' do
    result = strategy.jira_options(base)
    expect(result[:site]).to eq('https://jira.example.com')
  end

  it 'has a no-op post_init' do
    expect { strategy.post_init(double) }.not_to raise_error
  end
end
