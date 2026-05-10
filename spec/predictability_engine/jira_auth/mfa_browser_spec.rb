# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::JiraAuth::MfaBrowser do
  include_context 'with jira auth base options'

  def bearer_auth_header
    strategy.jira_options(base)[:default_headers]['Authorization']
  end

  describe 'manual-paste sub-mode (no idp_callback_port)' do
    subject(:strategy) { described_class.new(config) }

    let(:config) { { idp_login_url: 'https://sso.corp.com/login?next=%2Fjira' } }

    before do
      allow($stdin).to receive(:gets).and_return("my-pasted-token\n")
      allow($stdout).to receive(:puts)
      allow($stdout).to receive(:print)
    end

    it 'reads token from stdin and injects as Bearer header' do
      expect(bearer_auth_header).to eq('Bearer my-pasted-token')
    end

    it_behaves_like 'sets auth_type to basic'

    it 'raises when no token is pasted' do
      allow($stdin).to receive(:gets).and_return("\n")
      expect { strategy.jira_options(base) }.to raise_error(PredictabilityEngine::Error, /No token provided/)
    end

    it 'strips whitespace from pasted token' do
      allow($stdin).to receive(:gets).and_return("  tok-with-spaces  \n")
      expect(bearer_auth_header).to eq('Bearer tok-with-spaces')
    end
  end

  describe 'callback server sub-mode (idp_callback_port set)' do
    let(:config) { { idp_login_url: 'https://sso.corp.com/login', idp_callback_port: 19_876 } }
    let(:strategy) { described_class.new(config) }
    let(:server_double) do
      require 'webrick'
      instance_double(WEBrick::HTTPServer, shutdown: nil)
    end

    def stub_callback_server(token)
      allow(strategy).to receive(:build_callback_server) do |_port, queue|
        queue.push(token)
        server_double
      end
    end

    before do
      stub_callback_server('server-token')
      allow(strategy).to receive(:open_browser)
    end

    it 'captures the token from the callback and injects as Bearer header' do
      expect(bearer_auth_header).to eq('Bearer server-token')
    end

    it 'shuts down the server after receiving the token' do
      expect(server_double).to receive(:shutdown)
      strategy.jira_options(base)
    end

    it 'shuts down the server and raises when token is nil' do
      stub_callback_server(nil)
      expect(server_double).to receive(:shutdown)
      expect { strategy.jira_options(base) }.to raise_error(PredictabilityEngine::Error, /No token received/)
    end
  end
end
