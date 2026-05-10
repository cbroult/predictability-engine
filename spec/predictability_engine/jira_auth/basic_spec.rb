# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::JiraAuth::Basic do
  include_context 'with jira auth strategy'

  let(:config) { { email: 'user@example.com', token: 'my-token' } }

  it 'sets username, password, and auth_type' do
    expect(strategy.jira_options(base)).to include(
      username: 'user@example.com',
      password: 'my-token',
      auth_type: :basic
    )
  end

  it_behaves_like 'preserves base site'

  it 'has a no-op post_init' do
    expect { strategy.post_init(double) }.not_to raise_error
  end
end
