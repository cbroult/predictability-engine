# frozen_string_literal: true

RSpec.shared_context 'with jira auth base options' do
  let(:base) { { site: 'https://jira.example.com', context_path: nil, default_headers: {} } }
end

RSpec.shared_context 'with jira auth strategy' do
  subject(:strategy) { described_class.new(config) }

  include_context 'with jira auth base options'
end

RSpec.shared_examples 'sets auth_type to basic' do
  it 'sets auth_type to :basic' do
    expect(strategy.jira_options(base)[:auth_type]).to eq(:basic)
  end
end

RSpec.shared_examples 'preserves base site' do
  it 'preserves base options' do
    result = strategy.jira_options(base)
    expect(result[:site]).to eq('https://jira.example.com')
  end
end
