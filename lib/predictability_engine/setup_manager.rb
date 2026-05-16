# frozen_string_literal: true

require 'json'
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
      PredictabilityEngine.logger.info { '==> Installing Ruby dependencies' }
      Bundler.with_unbundled_env do
        system('bundle', 'install', '--jobs', '4', '--retry', '3') || raise(Error, 'bundle install failed')
      end
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
      raw = `node --version 2>/dev/null`.strip
      return nil if raw.empty?

      raw.delete_prefix('v').split('.').first.to_i
    rescue Errno::ENOENT
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
      return 'apt-get' if system('apt-get', '--version', out: File::NULL, err: File::NULL)
      return 'dnf'     if system('dnf', '--version', out: File::NULL, err: File::NULL)

      raise Error, 'No supported package manager found (tried apt-get, dnf) — install Node.js manually'
    end

    def install_or_update_playwright
      if !playwright_installed?
        PredictabilityEngine.logger.info { '==> Installing Playwright (first run)' }
        system('npm', 'install') || raise(Error, 'npm install failed')
      elsif playwright_outdated?
        PredictabilityEngine.logger.info { '==> Updating Playwright' }
        system('npm', 'update', 'playwright') || raise(Error, 'npm update playwright failed')
      else
        PredictabilityEngine.logger.info { '==> Playwright — already up to date' }
      end
      install_chromium_browser
    end

    def playwright_installed?
      File.exist?(File.join(gem_root, 'node_modules', '.bin', 'playwright'))
    end

    def playwright_outdated?
      raw = IO.popen(%w[npm outdated --json], err: File::NULL, &:read)
      JSON.parse(raw).key?('playwright')
    rescue JSON::ParserError
      false
    end

    def install_chromium_browser
      if ENV['PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD']
        PredictabilityEngine.logger.info { '==> Chromium install skipped (PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD set)' }
        return
      end

      system('npx', 'playwright', 'install', 'chromium', '--with-deps') ||
        raise(Error, 'playwright install chromium failed')
    end

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
