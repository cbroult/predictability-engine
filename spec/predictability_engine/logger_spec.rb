# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'

RSpec.describe PredictabilityEngine::Logger do
  let(:instance) { described_class.new }
  let(:io) { StringIO.new }

  before do
    console = Logger.new(io)
    console.formatter = proc { |_, _, _, msg| "#{msg}\n" }
    instance.instance_variable_set(:@console_logger, console)
  end

  def set_level(level)
    instance.instance_variable_get(:@console_logger).level = level
  end

  describe '#info with block' do
    it 'evaluates the block when the level is enabled' do
      set_level(Logger::INFO)
      instance.info { 'hello' }
      expect(io.string).to include('hello')
    end

    it 'does NOT evaluate the block when the level is disabled' do
      set_level(Logger::WARN)
      expect { instance.info { raise 'block must not run' } }.not_to raise_error
      expect(io.string).to eq('')
    end
  end

  describe '#warn with block' do
    it 'evaluates the block at WARN level' do
      set_level(Logger::WARN)
      instance.warn { 'uh-oh' }
      expect(io.string).to include('uh-oh')
    end
  end

  describe 'backward-compatible string form' do
    it 'still accepts a plain message argument' do
      set_level(Logger::INFO)
      instance.info('plain')
      expect(io.string).to include('plain')
    end
  end

  describe 'file logger fan-out' do
    it 'forwards the block to the file logger when configured' do
      Dir.mktmpdir do |dir|
        log_file = File.join(dir, 'pe.log')
        instance.setup(level: 'info', log_file: log_file)
        instance.info { 'fan-out' }
        expect(File.read(log_file)).to include('fan-out')
      end
    end
  end
end
