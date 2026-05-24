# frozen_string_literal: true

require 'spec_helper'
require 'predictability_engine/cli'

RSpec.describe PredictabilityEngine::Jira do
  subject(:jira_cli) { described_class.new }

  include_context 'with captured logger'

  describe '#init' do
    it 'appends .yml if missing' do
      allow(File).to receive(:write)
      jira_cli.init('test')
      expect(log_output.string).to match(/Template created at test.yml/)
    end

    it 'does not append .yml if already present' do
      allow(File).to receive(:write)
      jira_cli.init('test.yml')
      expect(log_output.string).to match(/Template created at test.yml/)
    end
  end

  describe '#config' do
    include_context 'with isolated home'

    let(:profile) { 'test-profile' }
    let(:credentials_path) { PredictabilityEngine::Config.jira_credentials_file }

    before do
      allow_any_instance_of(described_class).to receive(:ask).and_return('value')
    end

    it 'creates new file if it does not exist' do
      jira_cli.config(profile)
      expect(log_output.string).to match(/Jira credentials for profile 'test-profile' saved/)
      expect(File.exist?(credentials_path)).to be true
    end

    it 'updates existing file if it exists' do
      FileUtils.mkdir_p(File.dirname(credentials_path))
      File.write(credentials_path, { 'profiles' => { 'other' => {} } }.to_yaml)
      jira_cli.config(profile)
      config = YAML.load_file(credentials_path)
      expect(config['profiles']).to have_key('test-profile')
      expect(config['profiles']).to have_key('other')
    end
  end
end
