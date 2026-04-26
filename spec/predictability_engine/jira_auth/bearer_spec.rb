# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::JiraAuth::Bearer do
  subject(:strategy) { described_class.new(config) }

  let(:config) { { bearer_token: 'tok123' } }
  let(:base)   { { site: 'https://jira.example.com', context_path: nil, default_headers: {} } }

  it 'injects Authorization Bearer header' do
    result = strategy.jira_options(base)
    expect(result[:default_headers]).to eq('Authorization' => 'Bearer tok123')
  end

  it 'sets auth_type to :basic (suppresses Basic auth header)' do
    expect(strategy.jira_options(base)[:auth_type]).to eq(:basic)
  end

  it 'does not set username or password' do
    result = strategy.jira_options(base)
    expect(result).not_to have_key(:username)
    expect(result).not_to have_key(:password)
  end

  it 'preserves other base headers' do
    base_with_header = base.merge(default_headers: { 'X-Custom' => '1' })
    result = strategy.jira_options(base_with_header)
    expect(result[:default_headers]).to include('X-Custom' => '1', 'Authorization' => 'Bearer tok123')
  end
end
