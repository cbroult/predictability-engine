# frozen_string_literal: true

require 'net/https'
require 'uri'

module PredictabilityEngine
  module JiraAuth
    # Browser-assisted IdP authentication for MFA gateways.
    #
    # Two sub-modes selected by `idp_callback_port`:
    #
    # A. Manual-paste (default, no extra deps):
    #    Prints the idp_login_url and asks the user to paste back
    #    the resulting bearer token or cookie string.
    #
    # B. Local callback server (experimental, set idp_callback_port: PORT):
    #    Starts a WEBrick listener on localhost:PORT, opens the browser,
    #    captures the token/code from the redirect query params, then
    #    exchanges a code for a token if mfa_token_exchange_url is set.
    class MfaBrowser < Base
      CALLBACK_TIMEOUT = 120

      def jira_options(base_options)
        token = @config[:idp_callback_port] ? callback_server_flow : manual_paste_flow
        base_options.merge(
          auth_type: :basic,
          default_headers: base_options[:default_headers]
                           .merge('Authorization' => "Bearer #{token}")
        )
      end

      private

      def manual_paste_flow
        $stdout.puts "\nOpen this URL in your browser to authenticate:"
        $stdout.puts "  #{@config[:idp_login_url]}"
        $stdout.puts "\nAfter logging in, paste the bearer token below and press Enter:"
        $stdout.print '> '
        token = $stdin.gets.to_s.strip
        raise Error, 'No token provided' if token.empty?

        token
      end

      # @experimental
      def callback_server_flow
        require 'webrick'
        port = Integer(@config[:idp_callback_port])
        token_queue = Queue.new

        server = build_callback_server(port, token_queue)
        open_browser(callback_url(port))

        PredictabilityEngine.logger.info { "Waiting for IdP callback on port #{port}..." }
        token = Timeout.timeout(CALLBACK_TIMEOUT) { token_queue.pop }
        raise Error, 'No token received from IdP callback' if token.nil? || token.empty?

        token
      ensure
        server&.shutdown
      end

      def build_callback_server(port, token_queue)
        server = WEBrick::HTTPServer.new(Port: port, Logger: WEBrick::Log.new(nil, 0),
                                         AccessLog: [])
        server.mount_proc('/callback') do |req, res|
          token_queue.push(req.query['token'] || req.query['access_token'] || req.query['code'])
          res.body = 'Authentication received. You may close this tab.'
          server.shutdown
        end
        Thread.new { server.start }
        server
      end

      def callback_url(port)
        "#{@config[:idp_login_url]}&redirect_uri=#{URI.encode_www_form_component("http://localhost:#{port}/callback")}"
      end

      def open_browser(url)
        commands = %w[xdg-open open start]
        cmd = commands.find { |c| system("which #{c} > /dev/null 2>&1") }
        if cmd
          system("#{cmd} '#{url}'")
        else
          $stdout.puts "Could not open browser automatically. Please visit:\n  #{url}"
        end
      end
    end
  end
end
