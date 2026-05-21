# frozen_string_literal: true

require 'spec_helper'
require 'predictability_engine/setup_manager'

RSpec.describe PredictabilityEngine::SetupManager do
  let(:manager) { described_class.new }
  let(:gem_root) { manager.send(:gem_root) }

  include_context 'with captured logger'

  before do
    allow(Bundler).to receive(:with_unbundled_env).and_yield
    allow(manager).to receive_messages(system: true, windows?: false, with_deps?: false)
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
    subject(:install_ruby_deps!) { manager.send(:install_ruby_dependencies) }

    let(:bundle_args) { ['bundle', 'install', '--jobs', '4', '--retry', '3'] }
    let(:gemfile_path) { File.join(gem_root, 'Gemfile') }

    around do |example|
      old = ENV.fetch('BUNDLE_WITHOUT', nil)
      ENV.delete('BUNDLE_WITHOUT')
      example.run
    ensure
      ENV['BUNDLE_WITHOUT'] = old
    end

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(manager).to receive(:bundle_check).and_return(false)
    end

    context 'when no Gemfile exists in gem_root' do
      before { allow(File).to receive(:exist?).with(gemfile_path).and_return(false) }

      it 'skips bundle install' do
        expect(manager).not_to receive(:system).with(*bundle_args)
        install_ruby_deps!
      end

      it 'logs that bundle install was skipped' do
        install_ruby_deps!
        expect(log_output.string).to include('Skipping bundle install')
      end
    end

    context 'when Gemfile exists in gem_root' do
      before { allow(File).to receive(:exist?).with(gemfile_path).and_return(true) }

      it 'skips bundle install when dependencies are already satisfied' do
        allow(manager).to receive(:bundle_check).and_return(true)
        expect(manager).not_to receive(:system).with(*bundle_args)
        install_ruby_deps!
      end

      it 'runs bundle install inside an unbundled env' do
        expect(Bundler).to receive(:with_unbundled_env).and_yield
        expect(manager).to receive(:system).with(*bundle_args)
        install_ruby_deps!
      end

      it 'preserves BUNDLE_WITHOUT for nested bundle installs' do
        env = { 'BUNDLE_WITHOUT' => 'internal_ci' }
        old = ENV.fetch('BUNDLE_WITHOUT', nil)
        ENV['BUNDLE_WITHOUT'] = env.fetch('BUNDLE_WITHOUT')

        expect(manager).to receive(:system).with(env, *bundle_args)
        install_ruby_deps!
      ensure
        ENV['BUNDLE_WITHOUT'] = old
      end

      it 'raises when bundle install fails' do
        allow(manager).to receive(:system).with(*bundle_args).and_return(false)
        expect { install_ruby_deps! }
          .to raise_error(PredictabilityEngine::Error, /bundle install failed/)
      end
    end
  end

  describe '#windows?' do
    before { allow(manager).to receive(:windows?).and_call_original }

    it 'returns false on the current (Linux) test platform' do
      expect(manager.send(:windows?)).to be(false)
    end
  end

  describe '#with_deps?' do
    before { allow(manager).to receive(:with_deps?).and_call_original }

    {
      'Windows (root)' => [{ windows?: true,  root?: true  }, false],
      'Linux non-root' => [{ windows?: false, root?: false }, false],
      'Linux root' => [{ windows?: false, root?: true }, true]
    }.each do |desc, (stubs, expected)|
      it "returns #{expected} when #{desc}" do
        allow(manager).to receive_messages(**stubs)
        expect(manager.send(:with_deps?)).to be(expected)
      end
    end
  end

  describe '#npm_cmd' do
    it 'returns npm on non-Windows' do
      expect(manager.send(:npm_cmd)).to eq('npm')
    end
  end

  describe '#npx_cmd' do
    it 'returns npx on non-Windows' do
      expect(manager.send(:npx_cmd)).to eq('npx')
    end
  end

  describe '#node_major_version' do
    it 'returns the major version number' do
      allow(Open3).to receive(:capture2).with('node', '--version').and_return(["v20.11.0\n", nil])
      expect(manager.send(:node_major_version)).to eq(20)
    end

    it 'returns nil when node is not on PATH' do
      allow(Open3).to receive(:capture2).with('node', '--version').and_raise(Errno::ENOENT)
      expect(manager.send(:node_major_version)).to be_nil
    end

    it 'returns nil when node outputs nothing' do
      allow(Open3).to receive(:capture2).with('node', '--version').and_return(['', nil])
      expect(manager.send(:node_major_version)).to be_nil
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
    subject(:install_or_update!) { manager.send(:install_or_update_playwright) }

    let(:npm_update_args) { ['npm', 'update', 'playwright', { chdir: gem_root }] }

    before do
      allow(manager).to receive(:install_chromium_browser)
      allow(manager).to receive(:playwright_installed?).and_return(true)
    end

    shared_examples 'installs Chromium browser' do
      it 'calls install_chromium_browser' do
        expect(manager).to receive(:install_chromium_browser)
        install_or_update!
      end
    end

    context 'when Playwright is not installed' do
      before { allow(manager).to receive(:playwright_installed?).and_return(false) }

      it 'runs npm install in gem_root' do
        expect(manager).to receive(:system).with('npm', 'install', chdir: gem_root)
        install_or_update!
      end

      it_behaves_like 'installs Chromium browser'
    end

    context 'when Playwright is installed and outdated' do
      before { allow(manager).to receive(:playwright_outdated?).and_return(true) }

      it 'updates Playwright via npm in gem_root' do
        expect(manager).to receive(:system).with(*npm_update_args)
        install_or_update!
      end

      it_behaves_like 'installs Chromium browser'
    end

    context 'when Playwright is installed and current' do
      before { allow(manager).to receive(:playwright_outdated?).and_return(false) }

      it 'does not run npm update' do
        expect(manager).not_to receive(:system).with(*npm_update_args)
        install_or_update!
      end

      it 'logs that Playwright is already up to date' do
        install_or_update!
        expect(log_output.string).to include('already up to date')
      end

      it_behaves_like 'installs Chromium browser'
    end
  end

  describe '#install_chromium_browser' do
    subject(:install_chromium!) { manager.send(:install_chromium_browser) }

    context 'when PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD is set' do
      around do |example|
        old = ENV.fetch('PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD', nil)
        ENV['PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD'] = '1'
        example.run
        ENV['PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD'] = old
      end

      it 'skips the download' do
        expect(manager).not_to receive(:system)
        install_chromium!
      end

      it 'logs that the install was skipped' do
        install_chromium!
        expect(log_output.string).to include('Chromium install skipped')
      end
    end

    context 'when PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD is not set' do
      include_context 'with cleared PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD'

      it 'runs playwright install chromium without --with-deps when not root' do
        chromium_args = ['npx', 'playwright', 'install', 'chromium', { chdir: gem_root }]
        expect(manager).to receive(:system).with(*chromium_args)
        install_chromium!
      end

      it 'adds --with-deps when running as root' do
        allow(manager).to receive(:with_deps?).and_return(true)
        expect(manager).to receive(:system)
          .with('npx', 'playwright', 'install', 'chromium', '--with-deps', chdir: gem_root)
        install_chromium!
      end
    end
  end

  describe '#configure_git_hooks' do
    subject(:configure_hooks!) { manager.send(:configure_git_hooks) }

    let(:git_check) { ['git', 'rev-parse', '--is-inside-work-tree', { out: File::NULL, err: File::NULL }] }
    let(:git_config) { ['git', 'config', 'core.hooksPath', '.githooks'] }

    context 'when inside a git repository' do
      before { allow(manager).to receive(:system).with(*git_check).and_return(true) }

      it 'sets core.hooksPath to .githooks' do
        expect(manager).to receive(:system).with(*git_config)
        configure_hooks!
      end

      it 'logs that hooks are configured' do
        configure_hooks!
        expect(log_output.string).to include('Git hooks configured')
      end
    end

    context 'when not inside a git repository' do
      before { allow(manager).to receive(:system).with(*git_check).and_return(false) }

      it 'does not configure hooks' do
        expect(manager).not_to receive(:system).with(*git_config)
        configure_hooks!
      end

      it 'logs that hooks are skipped' do
        configure_hooks!
        expect(log_output.string).to include('Git hooks skipped')
      end
    end
  end

  context 'when on Windows' do
    include_context 'with cleared PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD'

    before do
      allow(manager).to receive(:windows?).and_return(true)
      allow(manager).to receive(:install_chromium_browser)
    end

    it 'npm_cmd returns npm.cmd' do
      expect(manager.send(:npm_cmd)).to eq('npm.cmd')
    end

    it 'npx_cmd returns npx.cmd' do
      expect(manager.send(:npx_cmd)).to eq('npx.cmd')
    end

    it 'install_or_update_playwright uses npm.cmd for initial install' do
      install_args = ['npm.cmd', 'install', { chdir: gem_root }]
      allow(manager).to receive(:playwright_installed?).and_return(false)
      expect(manager).to receive(:system).with(*install_args)
      manager.send(:install_or_update_playwright)
    end

    it 'install_or_update_playwright uses npm.cmd for update' do
      allow(manager).to receive_messages(playwright_installed?: true, playwright_outdated?: true)
      expect(manager).to receive(:system).with('npm.cmd', 'update', 'playwright', chdir: gem_root)
      manager.send(:install_or_update_playwright)
    end

    it 'install_chromium_browser omits --with-deps and uses npx.cmd' do
      allow(manager).to receive(:install_chromium_browser).and_call_original
      expect(manager).to receive(:system).with('npx.cmd', 'playwright', 'install', 'chromium', chdir: gem_root)
      manager.send(:install_chromium_browser)
    end
  end
end
