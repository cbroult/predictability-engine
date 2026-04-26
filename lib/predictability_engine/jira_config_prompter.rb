# frozen_string_literal: true

module PredictabilityEngine
  # Mixin providing interactive credential prompts for `jira_config --auth-mode`.
  # Relies on `ask` / `ask_secret` being defined by the including class (Thor).
  module JiraConfigPrompter
    def build_profile_data(site, context_path, mode)
      data = { 'site' => site }
      data['context_path'] = context_path unless context_path.strip.empty?
      data['auth_mode'] = mode unless mode == 'basic'
      data.merge!(prompt_auth_fields(mode))
      data
    end

    def prompt_auth_fields(mode)
      case mode
      when 'bearer'
        { 'bearer_token' => ask_secret('Bearer token:') }
      when 'cookie'
        { 'auth_cookie' => ask_secret('Session cookie (e.g., JSESSIONID=abc; crowd.token_key=xyz):') }
      when 'mfa_api'
        prompt_mfa_api_fields
      when 'mfa_browser'
        prompt_mfa_browser_fields
      else
        { 'email' => ask('Jira email:'), 'token' => ask_secret('Jira API token:') }
      end
    end

    private

    def prompt_mfa_api_fields
      field = ask('Token field in login response (default: access_token):').strip
      { 'email' => ask('Jira email:'),
        'password' => ask_secret('Password:'),
        'totp_secret' => ask_secret('TOTP secret (base32):'),
        'mfa_login_url' => ask('MFA API login URL:'),
        'mfa_token_field' => field.empty? ? 'access_token' : field }
    end

    def prompt_mfa_browser_fields
      port = ask('Callback port for local server (leave blank for manual-paste mode):').strip
      data = { 'idp_login_url' => ask('IdP login URL:') }
      data['idp_callback_port'] = Integer(port) unless port.empty?
      data
    end
  end
end
