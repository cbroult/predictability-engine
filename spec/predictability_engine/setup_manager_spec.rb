# frozen_string_literal: true

require 'spec_helper'
require 'predictability_engine/setup_manager'

RSpec.describe PredictabilityEngine::SetupManager do
  let(:manager) { described_class.new }

  include_context 'with captured logger'

  before do
    allow(Bundler).to receive(:with_unbundled_env).and_yield
    allow(manager).to receive(:system).and_return(true)
  end

  describe '#run' do
    before do
      allow(manager).to receive_messages(
        install_ruby_dependencies: nil,
        ensure_node: nil,
        install_or_update_playwright: nil,
        configure_git_hooks: nil
      )
    end

    it 'runs all setup phases in order' do
      expect(manager).to receive(:install_ruby_dependencies).ordered
      expect(manager).to receive(:ensure_node).ordered
      expect(manager).to receive(:install_or_update_playwright).ordered
      expect(manager).to receive(:configure_git_hooks).ordered
      manager.run
    end

    it 'logs setup complete' do
      manager.run
      expect(log_output.string).to include('Setup complete')
    end
  end

  describe '#install_ruby_dependencies' do
    let(:bundle_args) { ['bundle', 'install', '--jobs', '4', '--retry', '3'] }

    it 'runs bundle install inside an unbundled env' do
      expect(Bundler).to receive(:with_unbundled_env).and_yield
      expect(manager).to receive(:system).with(*bundle_args)
      manager.send(:install_ruby_dependencies)
    end

    it 'raises Error when bundle install fails' do
      allow(manager).to receive(:system).with(*bundle_args).and_return(false)
      expect { manager.send(:install_ruby_dependencies) }
        .to raise_error(PredictabilityEngine::Error, /bundle install failed/)
    end
  end

  describe '#ensure_node' do
    context 'when Node.js is absent' do
      before { allow(manager).to receive(:node_major_version).and_return(nil) }

      it 'installs Node.js' do
        expect(manager).to receive(:manage_node).with(:install)
        manager.send(:ensure_node)
      end
    end

    context 'when Node.js is below the minimum version' do
      before { allow(manager).to receive(:node_major_version).and_return(16) }

      it 'upgrades Node.js' do
        expect(manager).to receive(:manage_node).with(:upgrade)
        manager.send(:ensure_node)
      end
    end

    context 'when Node.js meets the minimum version' do
      before { allow(manager).to receive(:node_major_version).and_return(18) }

      it 'skips installation' do
        expect(manager).not_to receive(:manage_node)
        manager.send(:ensure_node)
      end

      it 'logs that Node.js is sufficient' do
        manager.send(:ensure_node)
        expect(log_output.string).to include('already sufficient')
      end
    end
  end

  describe '#install_or_update_playwright' do
    before { allow(manager).to receive(:install_chromium_browser) }

    context 'when Playwright is not installed' do
      before { allow(manager).to receive(:playwright_installed?).and_return(false) }

      it 'runs npm install' do
        expect(manager).to receive(:system).with('npm', 'install')
        manager.send(:install_or_update_playwright)
      end

      it 'installs the Chromium browser' do
        expect(manager).to receive(:install_chromium_browser)
        manager.send(:install_or_update_playwright)
      end
    end

    context 'when Playwright is installed and outdated' do
      before do
        allow(manager).to receive_messages(playwright_installed?: true, playwright_outdated?: true)
      end

      it 'updates Playwright via npm' do
        expect(manager).to receive(:system).with('npm', 'update', 'playwright')
        manager.send(:install_or_update_playwright)
      end

      it 'installs the Chromium browser after updating' do
        expect(manager).to receive(:install_chromium_browser)
        manager.send(:install_or_update_playwright)
      end
    end

    context 'when Playwright is installed and current' do
      before do
        allow(manager).to receive_messages(playwright_installed?: true, playwright_outdated?: false)
      end

      it 'does not run npm update' do
        expect(manager).not_to receive(:system).with('npm', 'update', 'playwright')
        manager.send(:install_or_update_playwright)
      end

      it 'still installs the Chromium browser' do
        expect(manager).to receive(:install_chromium_browser)
        manager.send(:install_or_update_playwright)
      end

      it 'logs that Playwright is already up to date' do
        manager.send(:install_or_update_playwright)
        expect(log_output.string).to include('already up to date')
      end
    end
  end

  describe '#install_chromium_browser' do
    let(:chromium_cmd) { ['npx', 'playwright', 'install', 'chromium', '--with-deps'] }

    context 'when PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD is set' do
      around do |example|
        old = ENV.fetch('PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD', nil)
        ENV['PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD'] = '1'
        example.run
        ENV['PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD'] = old
      end

      it 'skips the download' do
        expect(manager).not_to receive(:system).with(*chromium_cmd)
        manager.send(:install_chromium_browser)
      end

      it 'logs that the install was skipped' do
        manager.send(:install_chromium_browser)
        expect(log_output.string).to include('Chromium install skipped')
      end
    end

    context 'when PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD is not set' do
      around do |example|
        old = ENV.delete('PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD')
        example.run
        ENV['PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD'] = old if old
      end

      it 'runs playwright install chromium' do
        expect(manager).to receive(:system).with(*chromium_cmd)
        manager.send(:install_chromium_browser)
      end
    end
  end

  describe '#configure_git_hooks' do
    let(:git_check) { ['git', 'rev-parse', '--is-inside-work-tree', { out: File::NULL, err: File::NULL }] }
    let(:git_config) { ['git', 'config', 'core.hooksPath', '.githooks'] }

    context 'when inside a git repository' do
      before { allow(manager).to receive(:system).with(*git_check).and_return(true) }

      it 'sets core.hooksPath to .githooks' do
        expect(manager).to receive(:system).with(*git_config)
        manager.send(:configure_git_hooks)
      end

      it 'logs that hooks are configured' do
        manager.send(:configure_git_hooks)
        expect(log_output.string).to include('Git hooks configured')
      end
    end

    context 'when not inside a git repository' do
      before { allow(manager).to receive(:system).with(*git_check).and_return(false) }

      it 'does not configure hooks' do
        expect(manager).not_to receive(:system).with(*git_config)
        manager.send(:configure_git_hooks)
      end

      it 'logs that hooks are skipped' do
        manager.send(:configure_git_hooks)
        expect(log_output.string).to include('Git hooks skipped')
      end
    end
  end
end
