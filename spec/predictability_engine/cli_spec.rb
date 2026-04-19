# frozen_string_literal: true

require 'spec_helper'
require 'predictability_engine/cli'

RSpec.describe PredictabilityEngine::Cli do
  subject(:cli) { described_class.new }

  before do
    PredictabilityEngine::Logger.instance_variable_set(:@instance, nil)
  end

  let(:items) { [PredictabilityEngine::Models::WorkItem.new(item_id: '1', title: 'Task 1', start_date: '2024-01-01', end_date: '2024-01-05')] }
  let(:source) { 'sample.csv' }

  describe '#init' do
    it 'appends .yml if missing' do
      allow(File).to receive(:write)
      expect { cli.init('test') }.to output(/Template created at test.yml/).to_stdout
    end

    it 'does not append .yml if already present' do
      allow(File).to receive(:write)
      expect { cli.init('test.yml') }.to output(/Template created at test.yml/).to_stdout
    end
  end

  describe '#jira_config' do
    let(:profile) { 'test-profile' }
    let(:credentials_path) { 'tmp/jira_credentials_spec.yml' }

    before do
      stub_const('PredictabilityEngine::Config::JIRA_CREDENTIALS_FILE', credentials_path)
      # Use a real instance or avoid stubbing subject methods
      allow_any_instance_of(described_class).to receive(:ask).and_return('value')
      FileUtils.rm_f(credentials_path)
    end

    after do
      FileUtils.rm_f(credentials_path)
    end

    it 'creates new file if it does not exist' do
      expect { cli.jira_config(profile) }.to output(/Jira credentials for profile 'test-profile' saved/).to_stdout
      expect(File.exist?(credentials_path)).to be true
    end

    it 'updates existing file if it exists' do
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

    before do
      allow(PredictabilityEngine::DataManager).to receive(:new).and_return(manager)
      allow(PredictabilityEngine::Agents::Assistant).to receive(:new).and_return(assistant)
    end

    it 'outputs content if response responds to :content' do
      # Use a plain object or instance_double if the class was available
      response = Object.new
      def response.content = 'AI Answer'
      allow(assistant).to receive(:ask).and_return(response)

      expect { cli.ask_ai(source, 'question') }.to output(/AI Answer/).to_stdout
    end

    it 'outputs response directly if it does not respond to :content' do
      allow(assistant).to receive(:ask).and_return('AI Raw Answer')

      expect { cli.ask_ai(source, 'question') }.to output(/AI Raw Answer/).to_stdout
    end
  end

  describe PredictabilityEngine::Viz do
    subject(:viz) { described_class.new([], { color: true }) }

    before do
      allow(PredictabilityEngine).to receive(:load_items).with(source).and_return(items)
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
