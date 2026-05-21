# frozen_string_literal: true

require 'json'
require 'open3'
require 'bundler'

module PredictabilityEngine
  class SetupManager
    NODE_MIN_MAJOR = 18
    private_constant :NODE_MIN_MAJOR

    def run
      install_ruby_dependencies
      ensure_node
      install_or_update_playwright
      configure_git_hooks
      PredictabilityEngine.logger.info { <<~MSG }
        Setup complete. Try:
          predictability-engine summary data/samples/sample_data.csv
      MSG
    end

    private

    def install_ruby_dependencies
      unless File.exist?(File.join(gem_root, 'Gemfile'))
        PredictabilityEngine.logger.info { '==> Skipping bundle install (no Gemfile — gem install mode)' }
        return
      end
      PredictabilityEngine.logger.info { '==> Installing Ruby dependencies' }
      return if bundle_check

      Bundler.with_unbundled_env do
        bundle_install || raise(Error, 'bundle install failed')
      end
    end

    def bundle_check = run_bundle_command('check', out: File::NULL, err: File::NULL)

    def bundle_install = run_bundle_command('install', '--jobs', '4', '--retry', '3')

    def run_bundle_command(*args)
      env = bundle_install_env
      command = ['bundle', *args]
      env.empty? ? system(*command) : system(env, *command)
    end

    def bundle_install_env
      without = ENV.fetch('BUNDLE_WITHOUT', nil)
      without.to_s.empty? ? {} : { 'BUNDLE_WITHOUT' => without }
    end

    def ensure_node
      current = node_major_version
      if current.nil?
        PredictabilityEngine.logger.info { '==> Installing Node.js' }
        manage_node(:install)
      elsif current < NODE_MIN_MAJOR
        PredictabilityEngine.logger.info { "==> Upgrading Node.js (found v#{current}, need v#{NODE_MIN_MAJOR}+)" }
        manage_node(:upgrade)
      else
        PredictabilityEngine.logger.info { "==> Node.js v#{current} — already sufficient" }
      end
    end

    def node_major_version
      out, = Open3.capture2('node', '--version')
      raw = out.strip
      return nil if raw.empty?

      raw.delete_prefix('v').split('.').first.to_i
    rescue Errno::ENOENT, Errno::EACCES
      nil
    end

    def manage_node(action)
      cmd = node_cmd_for(action)
      system(*cmd) || raise(Error, "Node.js #{action} failed on #{Gem::Platform.local.os}")
    end

    def node_cmd_for(action)
      case Gem::Platform.local.os
      when 'darwin'
        action == :install ? %w[brew install node] : %w[brew upgrade node]
      when 'linux'
        [linux_node_package_manager, 'install', '-y', 'nodejs']
      when /mingw/
        action == :install ? %w[choco install nodejs -y] : %w[choco upgrade nodejs -y]
      else
        os = Gem::Platform.local.os
        raise Error, "Cannot auto-install Node.js on '#{os}' — install Node #{NODE_MIN_MAJOR}+ manually"
      end
    end

    def linux_node_package_manager
      %w[apt-get dnf].each do |pm|
        return pm if system(pm, '--version', out: File::NULL, err: File::NULL)
      end
      raise Error, 'No supported package manager found (tried apt-get, dnf) — install Node.js manually'
    end

    def install_or_update_playwright
      if !playwright_installed?
        PredictabilityEngine.logger.info { '==> Installing Playwright (first run)' }
        system(npm_cmd, 'install', chdir: gem_root) || raise(Error, 'npm install failed')
      elsif playwright_outdated?
        PredictabilityEngine.logger.info { '==> Updating Playwright' }
        system(npm_cmd, 'update', 'playwright', chdir: gem_root) || raise(Error, 'npm update playwright failed')
      else
        PredictabilityEngine.logger.info { '==> Playwright — already up to date' }
      end
      install_chromium_browser
    end

    def playwright_installed?
      File.exist?(File.join(gem_root, 'node_modules', 'playwright', 'package.json'))
    end

    def playwright_outdated?
      raw = IO.popen([npm_cmd, 'outdated', '--json'], chdir: gem_root, err: File::NULL, &:read)
      JSON.parse(raw).key?('playwright')
    rescue JSON::ParserError
      false
    end

    def install_chromium_browser
      if ENV['PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD']
        PredictabilityEngine.logger.info { '==> Chromium install skipped (PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD set)' }
        return
      end

      args = [npx_cmd, 'playwright', 'install', 'chromium']
      args << '--with-deps' if with_deps?
      system(*args, chdir: gem_root) || raise(Error, 'playwright install chromium failed')
    end

    def windows?
      !!(Gem::Platform.local.os =~ /mingw|mswin/)
    end

    # --with-deps installs OS-level libraries via apt-get/dnf and requires root.
    # Only enable it when running as root (e.g. CI Docker containers).
    def with_deps?
      !windows? && root?
    end

    def root?
      Process.euid.zero?
    end

    def npm_cmd = windows? ? 'npm.cmd' : 'npm'
    def npx_cmd = windows? ? 'npx.cmd' : 'npx'

    def gem_root
      File.expand_path('../..', __dir__)
    end

    def configure_git_hooks
      if system('git', 'rev-parse', '--is-inside-work-tree', out: File::NULL, err: File::NULL)
        system('git', 'config', 'core.hooksPath', '.githooks') ||
          raise(Error, 'git config core.hooksPath failed')
        PredictabilityEngine.logger.info { '==> Git hooks configured (.githooks)' }
      else
        PredictabilityEngine.logger.info { '==> Git hooks skipped (not a git repository)' }
      end
    end
  end
end
