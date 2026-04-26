# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PredictabilityEngine::JiraAuth::MfaApi do
  subject(:strategy) { described_class.new(config) }

  let(:config) do
    {
      email: 'user@corp.com',
      password: 'secret',
      totp_secret: 'JBSWY3DPEHPK3PXP',
      mfa_login_url: 'https://keycloak.corp.com/token',
      mfa_token_field: 'access_token'
    }
  end
  let(:base) { { site: 'https://jira.corp.com', context_path: nil, default_headers: {} } }

  def stub_totp(otp = '123456')
    totp = instance_double(ROTP::TOTP, now: otp)
    allow(ROTP::TOTP).to receive(:new).with('JBSWY3DPEHPK3PXP').and_return(totp)
  end

  def stub_http_ok(body)
    response = instance_double(Net::HTTPOK, is_a?: true, body: body, code: '200')
    allow(response).to receive(:is_a?).with(Net::HTTPOK).and_return(true)
    allow(Net::HTTP).to receive(:post).and_return(response)
  end

  def stub_http_error(code, body)
    response = instance_double(Net::HTTPResponse, is_a?: false, body: body, code: code)
    allow(response).to receive(:is_a?).with(Net::HTTPOK).and_return(false)
    allow(Net::HTTP).to receive(:post).and_return(response)
  end

  describe '#jira_options' do
    before { stub_totp }

    context 'when login succeeds' do
      before { stub_http_ok('{"access_token":"mfa-bearer-tok"}') }

      it 'fetches a bearer token via TOTP + API login' do
        result = strategy.jira_options(base)
        expect(result[:default_headers]).to eq('Authorization' => 'Bearer mfa-bearer-tok')
      end

      it 'sets auth_type to :basic' do
        expect(strategy.jira_options(base)[:auth_type]).to eq(:basic)
      end

      it 'posts the email, password, and OTP to the login URL' do
        expect(Net::HTTP).to receive(:post) do |uri, payload_json, _headers|
          payload = JSON.parse(payload_json)
          expect(uri.to_s).to eq('https://keycloak.corp.com/token')
          expect(payload).to include('username' => 'user@corp.com', 'password' => 'secret', 'otp' => '123456')
          instance_double(Net::HTTPOK, is_a?: true, body: '{"access_token":"tok"}', code: '200').tap do |r|
            allow(r).to receive(:is_a?).with(Net::HTTPOK).and_return(true)
          end
        end
        strategy.jira_options(base)
      end
    end

    context 'when mfa_token_field is not set' do
      let(:config) { super().merge(mfa_token_field: nil) }

      before { stub_http_ok('{"access_token":"mfa-bearer-tok"}') }

      it 'defaults to access_token field' do
        result = strategy.jira_options(base)
        expect(result[:default_headers]['Authorization']).to eq('Bearer mfa-bearer-tok')
      end
    end

    context 'when the MFA login fails' do
      before { stub_http_error('401', 'Unauthorized') }

      it 'raises an error' do
        expect { strategy.jira_options(base) }.to raise_error(PredictabilityEngine::Error, /MFA login failed/)
      end
    end

    context 'when the token field is missing from response' do
      before { stub_http_ok('{"other_field":"value"}') }

      it 'raises an error' do
        expect { strategy.jira_options(base) }.to raise_error(PredictabilityEngine::Error, /missing field/)
      end
    end
  end
end
