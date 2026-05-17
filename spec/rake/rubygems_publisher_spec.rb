# frozen_string_literal: true

require 'spec_helper'

require_relative '../../rakelib/rubygems_publisher'

RSpec.describe RubygemsPublisher do
  let(:publisher) do
    instance_double(Rake::Gem::Maintenance::GemPublisher, publish: nil, successful_repos: ['rubygems'])
  end

  before do
    allow(Rake::Gem::Maintenance::GemPublisher).to receive(:new).and_return(publisher)
    allow(Dir).to receive(:glob).with('*.gem').and_return(['predictability-engine-0.6.0.gem'])
    Rake::Gem::Maintenance::Repos.rubygems_api_key_env_var = nil
    Rake::Gem::Maintenance::Repos.rubygems_otp_seed_env_var = nil
  end

  describe '.publish' do
    it 'configures the API key and OTP seed env vars before publishing' do
      described_class.publish
      expect(Rake::Gem::Maintenance::Repos.rubygems_api_key_env_var).to eq('GEM_HOST_API_KEY')
      expect(Rake::Gem::Maintenance::Repos.rubygems_otp_seed_env_var).to eq('RUBYGEMS_OTP_SEED')
    end

    it 'raises when no .gem file is found' do
      allow(Dir).to receive(:glob).with('*.gem').and_return([])
      expect { described_class.publish }.to raise_error(RuntimeError, /No .gem file found/)
    end

    it 'raises when the push to rubygems.org fails' do
      allow(publisher).to receive(:successful_repos).and_return([])
      expect { described_class.publish }.to raise_error(RuntimeError, /failed/)
    end

    it 'succeeds without raising when the publish succeeds' do
      expect { described_class.publish }.not_to raise_error
    end
  end
end
