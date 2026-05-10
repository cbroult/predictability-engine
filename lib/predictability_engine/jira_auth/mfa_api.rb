# frozen_string_literal: true

require 'net/https'
require 'json'
require 'rotp'

module PredictabilityEngine
  module JiraAuth
    class MfaApi < Base
      def jira_options(base_options)
        bearer_merge(base_options, fetch_token)
      end

      private

      def fetch_token
        otp = ROTP::TOTP.new(@config[:totp_secret]).now
        uri = URI(@config[:mfa_login_url])
        response = Net::HTTP.post(uri, build_payload(otp).to_json, 'Content-Type' => 'application/json')
        raise Error, "MFA login failed (HTTP #{response.code}): #{response.body}" unless response.is_a?(Net::HTTPOK)

        JSON.parse(response.body).fetch(token_field) do
          raise Error, "MFA login response missing field '#{token_field}'"
        end
      end

      def build_payload(otp)
        { username: @config[:email], password: @config[:password], otp: otp }
      end

      def token_field
        @config[:mfa_token_field] || 'access_token'
      end
    end
  end
end
