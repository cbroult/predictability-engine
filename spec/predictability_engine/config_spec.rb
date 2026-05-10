# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::Config do
  include_context 'with isolated home'

  let(:config_file) { described_class::CONFIG_FILE }

  after { FileUtils.rm_f(config_file) }

  describe '.jira' do
    subject(:context_path) { described_class.jira[:context_path] }

    def clean_env
      ENV.to_h.reject { |k, _| k.start_with?('JIRA_') }
    end

    context 'without profile_name' do
      it 'handles environment and global fallbacks' do
        # 1. Environment variables
        stub_const('ENV', clean_env.merge('JIRA_SITE' => 'https://env.net'))
        expect(described_class.jira[:site]).to eq('https://env.net')

        # 2. File fallback
        write_config({ 'jira' => { 'site' => 'https://file.net' } })
        stub_const('ENV', clean_env)
        expect(described_class.jira[:site]).to eq('https://file.net')

        # 3. Profile from environment
        write_config({ 'jira' => { 'profiles' => { 'p' => { 'site' => 'https://p.net' } } } })
        stub_const('ENV', clean_env.merge('JIRA_PROFILE' => 'p'))
        expect(described_class.jira[:site]).to eq('https://p.net')
      end

      it 'returns project key accurately' do
        stub_const('ENV', clean_env.merge('JIRA_PROJECT' => 'ENV-P'))
        expect(described_class.jira[:project]).to eq('ENV-P')

        stub_const('ENV', clean_env)
        write_config({ 'jira' => { 'project' => 'FILE-P' } })
        expect(described_class.jira[:project]).to eq('FILE-P')
      end
    end

    context 'with profile_name' do
      let(:p_profile) { { 'p' => { 'site' => 'https://p.net' } } }

      it 'prioritizes profile specific settings' do
        write_config({ 'jira' => { 'profiles' => p_profile } })
        expect(described_class.jira('p')[:site]).to eq('https://p.net')
      end

      it 'prevents global setting leak to profile' do
        write_config({ 'jira' => { 'email' => 'g@e.com', 'profiles' => p_profile } })
        expect(described_class.jira('p')[:email]).to be_nil
      end

      it 'loads context_path from profile' do
        profile = { 'q' => { 'site' => 'https://q.net', 'context_path' => '/jira' } }
        write_config({ 'jira' => { 'profiles' => profile } })
        expect(described_class.jira('q')[:context_path]).to eq('/jira')
      end
    end

    context 'when context_path is set via global config file' do
      before do
        write_config({ 'jira' => { 'site' => 'https://host.net', 'context_path' => '/jira' } })
        stub_const('ENV', clean_env)
      end

      it { is_expected.to eq('/jira') }
    end

    context 'when context_path is set via JIRA_CONTEXT_PATH env var' do
      before { stub_const('ENV', clean_env.merge('JIRA_SITE' => 'https://host.net', 'JIRA_CONTEXT_PATH' => '/jira')) }

      it { is_expected.to eq('/jira') }
    end

    context 'when context_path is not configured' do
      before { stub_const('ENV', clean_env.merge('JIRA_SITE' => 'https://cloud.atlassian.net')) }

      it { is_expected.to be_nil }
    end

    def write_config(data)
      File.write(config_file, data.to_yaml)
    end
  end

  describe '.jira_client http_debug' do
    let(:base_options) { { site: 'https://jira.example.com', context_path: nil, auth_type: :basic } }
    let(:auth_double) do
      instance_double(PredictabilityEngine::JiraAuth::Basic,
                      jira_options: base_options,
                      post_init: nil)
    end
    let(:client_double) { instance_double(JIRA::Client) }

    before do
      require 'jira-ruby'
      allow(described_class).to receive(:jira).and_return(
        { site: 'https://jira.example.com', email: 'u@e.com', token: 't' }
      )
      allow(described_class).to receive(:validate_jira!)
      allow(PredictabilityEngine::JiraAuth).to receive(:build).and_return(auth_double)
      allow(JIRA::Client).to receive(:new).and_return(client_double)
    end

    def captured_client_options
      described_class.jira_client
      captured = nil
      expect(JIRA::Client).to have_received(:new) { |opts| captured = opts }
      captured
    end

    context 'when JIRA_HTTP_DEBUG=true' do
      before { stub_const('ENV', ENV.to_h.merge('JIRA_HTTP_DEBUG' => 'true')) }

      it 'passes http_debug: true to JIRA::Client' do
        expect(captured_client_options[:http_debug]).to be true
      end
    end

    context 'when JIRA_HTTP_DEBUG is not set' do
      before { stub_const('ENV', ENV.to_h.except('JIRA_HTTP_DEBUG')) }

      it 'does not pass http_debug to JIRA::Client' do
        expect(captured_client_options).not_to have_key(:http_debug)
      end
    end
  end
end
