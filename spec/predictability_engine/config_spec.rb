# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::Config do
  include_context 'with isolated home'

  let(:config_file) { described_class::CONFIG_FILE }

  after { FileUtils.rm_f(config_file) }

  describe '.jira' do
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

    context 'when context_path is configured' do
      it 'loads context_path from global config file' do
        write_config({ 'jira' => { 'site' => 'https://host.net', 'context_path' => '/jira' } })
        stub_const('ENV', clean_env)
        expect(described_class.jira[:context_path]).to eq('/jira')
      end

      it 'loads context_path from JIRA_CONTEXT_PATH env var' do
        stub_const('ENV', clean_env.merge(
                            'JIRA_SITE' => 'https://host.net',
                            'JIRA_CONTEXT_PATH' => '/jira'
                          ))
        expect(described_class.jira[:context_path]).to eq('/jira')
      end

      it 'returns nil context_path when not configured' do
        stub_const('ENV', clean_env.merge('JIRA_SITE' => 'https://cloud.atlassian.net'))
        expect(described_class.jira[:context_path]).to be_nil
      end
    end

    def write_config(data)
      File.write(config_file, data.to_yaml)
    end
  end
end
