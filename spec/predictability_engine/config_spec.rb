# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::Config do
  let(:config_file) { described_class::CONFIG_FILE }

  after { File.delete(config_file) if File.exist?(config_file) }

  describe '.jira' do
    context 'without profile_name' do
      it 'uses environment variables by default' do
        stub_const('ENV', ENV.to_h.merge('JIRA_SITE' => 'https://env.atlassian.net'))
        expect(described_class.jira[:site]).to eq('https://env.atlassian.net')
      end

      it 'does not use global jira settings from file' do
        File.write(config_file, { 'jira' => { 'site' => 'https://global.atlassian.net' } }.to_yaml)
        expect(described_class.jira[:site]).to be_nil
      end
    end

    context 'with profile_name' do
      let(:yaml_content) do
        {
          'jira' => {
            'site' => 'https://global.atlassian.net',
            'profiles' => {
              'client-x' => { 'site' => 'https://client-x.atlassian.net' }
            }
          }
        }.to_yaml
      end

      before { File.write(config_file, yaml_content) }

      it 'uses profile specific settings' do
        expect(described_class.jira('client-x')[:site]).to eq('https://client-x.atlassian.net')
      end

      it 'does not fall back to global settings if profile is missing key' do
        expect(described_class.jira('client-x')[:email]).to be_nil
        # Let's add email to global
        File.write(config_file, {
          'jira' => {
            'email' => 'global@example.com',
            'profiles' => { 'client-x' => { 'site' => 'https://client-x.atlassian.net' } }
          }
        }.to_yaml)
        expect(described_class.jira('client-x')[:email]).to be_nil
      end
    end
  end
end
