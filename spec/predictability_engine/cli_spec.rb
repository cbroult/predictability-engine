# frozen_string_literal: true

require 'spec_helper'
require 'predictability_engine/cli'

RSpec.describe PredictabilityEngine::Cli do
  subject(:cli) { described_class.new }

  include_context 'with captured logger'

  let(:items) { [PredictabilityEngine::Models::WorkItem.new(item_id: '1', title: 'Task 1', start_date: '2024-01-01', end_date: '2024-01-05')] }
  let(:source) { 'sample.csv' }

  describe '#version' do
    it 'prints the version to stdout' do
      expect { cli.version }.to output("#{PredictabilityEngine::VERSION}\n").to_stdout
    end
  end

  describe 'package name' do
    it 'includes the version number' do
      expect(described_class.instance_variable_get(:@package_name)).to include(PredictabilityEngine::VERSION)
    end
  end

  describe '#init' do
    it 'appends .yml if missing' do
      allow(File).to receive(:write)
      cli.init('test')
      expect(log_output.string).to match(/Template created at test.yml/)
    end

    it 'does not append .yml if already present' do
      allow(File).to receive(:write)
      cli.init('test.yml')
      expect(log_output.string).to match(/Template created at test.yml/)
    end
  end

  describe '#jira_config' do
    include_context 'with isolated home'

    let(:profile) { 'test-profile' }
    let(:credentials_path) { PredictabilityEngine::Config.jira_credentials_file }

    before do
      allow_any_instance_of(described_class).to receive(:ask).and_return('value')
    end

    it 'creates new file if it does not exist' do
      cli.jira_config(profile)
      expect(log_output.string).to match(/Jira credentials for profile 'test-profile' saved/)
      expect(File.exist?(credentials_path)).to be true
    end

    it 'updates existing file if it exists' do
      FileUtils.mkdir_p(File.dirname(credentials_path))
      File.write(credentials_path, { 'profiles' => { 'other' => {} } }.to_yaml)
      cli.jira_config(profile)
      config = YAML.load_file(credentials_path)
      expect(config['profiles']).to have_key('test-profile')
      expect(config['profiles']).to have_key('other')
    end
  end

  describe '#ask_ai' do
    let(:manager) { instance_double(PredictabilityEngine::DataManager, load: true) }
    let(:assistant) { instance_double(PredictabilityEngine::Agents::Assistant) }
    let(:ai_response) { 'AI Raw Answer' }

    before do
      allow(PredictabilityEngine::DataManager).to receive(:new).and_return(manager)
      allow(PredictabilityEngine::Agents::Assistant).to receive(:new).and_return(assistant)
      allow(assistant).to receive(:ask).and_return(ai_response)
    end

    it 'outputs content if response responds to :content' do
      response = Object.new
      def response.content = 'AI Answer'
      allow(assistant).to receive(:ask).and_return(response)

      cli.ask_ai(source, 'question')
      expect(log_output.string).to match(/AI Answer/)
    end

    it 'outputs response directly if it does not respond to :content' do
      cli.ask_ai(source, 'question')
      expect(log_output.string).to match(/AI Raw Answer/)
    end
  end

  describe PredictabilityEngine::CliBase do
    describe 'VALID_SIZES' do
      it 'is derived from RESOLUTION_CONFIG keys' do
        expect(PredictabilityEngine::CliBase::VALID_SIZES).to eq(
          PredictabilityEngine::Report::Constants::RESOLUTION_CONFIG.keys
        )
      end

      it 'includes a4 as the default size' do
        expect(PredictabilityEngine::CliBase::VALID_SIZES).to include(
          PredictabilityEngine::Report::Constants::DEFAULT_SIZE
        )
      end

      it 'includes all standard sizes' do
        expect(PredictabilityEngine::CliBase::VALID_SIZES).to include('5k', '4k', 'hd', 'a0', 'a4', 'a6')
      end
    end

    describe 'SIZE_DESC' do
      it 'lists all valid sizes' do
        PredictabilityEngine::CliBase::VALID_SIZES.each do |size|
          expect(PredictabilityEngine::CliBase::SIZE_DESC).to include(size)
        end
      end
    end
  end

  describe PredictabilityEngine::Viz do
    subject(:viz) { described_class.new([], { color: true }) }

    before do
      allow(PredictabilityEngine::Report).to receive(:generate_all).with(items).and_return({})
      allow(PredictabilityEngine).to receive(:load_items).with(source, url_prefix: nil).and_return(items)
    end

    describe '#all_formats' do
      it 'rescues and warns on StandardError' do
        allow(PredictabilityEngine).to receive(:run_and_print_report)
        allow(PredictabilityEngine).to receive(:run_and_print_report).with(source, :terminal, any_args).and_raise(
          StandardError, 'Oops'
        )

        expect(PredictabilityEngine.logger).to receive(:warn) do |_, &block|
          expect(block.call).to match(/Failed to generate terminal report: Oops/)
        end
        viz.all_formats(source)
      end
    end

    describe '#generate_output_path' do
      it 'returns provided output if present' do
        expect(viz.send(:generate_output_path, source, 'custom.html', 'default.html')).to eq('custom.html')
      end

      it 'returns generated path if output is nil' do
        expect(viz.send(:generate_output_path, source, nil,
                        'default.html')).to match(%r{(./)?reports/sample/default.html})
      end
    end
  end
end
