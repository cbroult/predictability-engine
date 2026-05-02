# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'PredictabilityEngine logging' do
  include_context 'with captured logger'

  def log_capture(level: :info)
    SemanticLogger.default_level = level
    yield
    SemanticLogger.flush
    log_output.string
  end

  describe '#info with block' do
    it 'evaluates the block when the level is enabled' do
      expect(log_capture { PredictabilityEngine.logger.info { 'hello' } }).to include('hello')
    end

    it 'does NOT evaluate the block when the level is disabled' do
      SemanticLogger.default_level = :warn
      expect { PredictabilityEngine.logger.info { raise 'block must not run' } }.not_to raise_error
    end
  end

  describe '#warn with block' do
    it 'evaluates the block at WARN level' do
      expect(log_capture(level: :warn) { PredictabilityEngine.logger.warn { 'uh-oh' } }).to include('uh-oh')
    end
  end

  describe 'backward-compatible string form' do
    it 'still accepts a plain message argument' do
      expect(log_capture { PredictabilityEngine.logger.info('plain') }).to include('plain')
    end
  end

  describe 'file logger fan-out' do
    it 'forwards the block to the file logger when configured' do
      Dir.mktmpdir do |dir|
        log_file = File.join(dir, 'pe.log')
        PredictabilityEngine.setup_logging(level: 'info', log_file: log_file)
        PredictabilityEngine.logger.info { 'fan-out' }
        SemanticLogger.flush
        expect(File.read(log_file)).to include('fan-out')
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
