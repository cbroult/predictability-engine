# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::JiraAuth::Cookie do
  subject(:strategy) { described_class.new(config) }

  include_context 'with jira auth base options'

  let(:config) { { auth_cookie: 'JSESSIONID=abc; crowd.token_key=xyz' } }

  it 'enables cookie mode with the configured cookie' do
    result = strategy.jira_options(base)
    expect(result).to include(
      auth_type: :basic,
      use_cookies: true,
      additional_cookies: ['JSESSIONID=abc; crowd.token_key=xyz']
    )
  end

  it_behaves_like 'preserves base site'
end
