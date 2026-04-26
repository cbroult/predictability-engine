# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::JiraAuth::Cookie do
  subject(:strategy) { described_class.new(config) }

  let(:config) { { auth_cookie: 'JSESSIONID=abc; crowd.token_key=xyz' } }
  let(:base)   { { site: 'https://jira.example.com', context_path: nil, default_headers: {} } }

  it 'enables cookie mode with the configured cookie' do
    result = strategy.jira_options(base)
    expect(result).to include(
      auth_type: :basic,
      use_cookies: true,
      additional_cookies: ['JSESSIONID=abc; crowd.token_key=xyz']
    )
  end

  it 'preserves base options' do
    result = strategy.jira_options(base)
    expect(result[:site]).to eq('https://jira.example.com')
  end
end
