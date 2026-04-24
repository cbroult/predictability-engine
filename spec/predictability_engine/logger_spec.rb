# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'PredictabilityEngine logging' do
  around do |example|
    orig_level = SemanticLogger.default_level
    orig_appenders = SemanticLogger.appenders.dup
    SemanticLogger.appenders.dup.each { |a| SemanticLogger.remove_appender(a) }
    example.run
    SemanticLogger.flush
    SemanticLogger.appenders.dup.each { |a| SemanticLogger.remove_appender(a) }
    orig_appenders.each { |a| SemanticLogger.add_appender(a) }
    SemanticLogger.default_level = orig_level
  end

  describe '#info with block' do
    it 'evaluates the block when the level is enabled' do
      io = StringIO.new
      SemanticLogger.default_level = :info
      SemanticLogger.add_appender(io: io, formatter: :default)
      PredictabilityEngine.logger.info { 'hello' }
      SemanticLogger.flush
      expect(io.string).to include('hello')
    end

    it 'does NOT evaluate the block when the level is disabled' do
      SemanticLogger.default_level = :warn
      expect { PredictabilityEngine.logger.info { raise 'block must not run' } }.not_to raise_error
    end
  end

  describe '#warn with block' do
    it 'evaluates the block at WARN level' do
      io = StringIO.new
      SemanticLogger.default_level = :warn
      SemanticLogger.add_appender(io: io, formatter: :default)
      PredictabilityEngine.logger.warn { 'uh-oh' }
      SemanticLogger.flush
      expect(io.string).to include('uh-oh')
    end
  end

  describe 'backward-compatible string form' do
    it 'still accepts a plain message argument' do
      io = StringIO.new
      SemanticLogger.default_level = :info
      SemanticLogger.add_appender(io: io, formatter: :default)
      PredictabilityEngine.logger.info('plain')
      SemanticLogger.flush
      expect(io.string).to include('plain')
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
