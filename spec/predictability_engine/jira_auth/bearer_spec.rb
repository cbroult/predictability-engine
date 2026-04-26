# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::JiraAuth::Bearer do
  subject(:strategy) { described_class.new(config) }

  include_context 'with jira auth base options'

  let(:config) { { bearer_token: 'tok123' } }

  it 'injects Authorization Bearer header' do
    result = strategy.jira_options(base)
    expect(result[:default_headers]).to eq('Authorization' => 'Bearer tok123')
  end

  it_behaves_like 'sets auth_type to basic'

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
