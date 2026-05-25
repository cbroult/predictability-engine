# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'tmpdir'

require_relative '../../rakelib/erb_processor'

RSpec.describe ErbProcessor do
  let(:ruby_version) { '4.0.3' }
  let(:node_version) { '26.2.0' }

  before do
    allow(described_class).to receive_messages(ruby_version: ruby_version, node_version: node_version)
  end

  def with_temp_erb(content)
    Tempfile.create(['tpl', '.erb']) do |f|
      f.write(content)
      f.flush
      yield f.path
    end
  end

  describe '.ruby_version' do
    it 'reads the version from .ruby-version stripping the ruby- prefix' do
      allow(described_class).to receive(:ruby_version).and_call_original
      allow(File).to receive(:read).with(ErbProcessor::RUBY_VERSION_FILE)
                                   .and_return("ruby-#{ruby_version}\n")
      expect(described_class.ruby_version).to eq(ruby_version)
    end
  end

  describe '.node_version' do
    it 'reads the version from .tool-versions nodejs line' do
      allow(described_class).to receive(:node_version).and_call_original
      allow(File).to receive(:read).with(ErbProcessor::TOOL_VERSIONS_FILE)
                                   .and_return("ruby 4.0.3\nnodejs #{node_version}\n")
      expect(described_class.node_version).to eq(node_version)
    end
  end

  describe '#render' do
    it 'substitutes ruby_version in an ERB template' do
      with_temp_erb('ruby <%= ruby_version %>') do |path|
        expect(described_class.new(path).render).to eq("ruby #{ruby_version}")
      end
    end

    it 'substitutes node_version and node_major in an ERB template' do
      with_temp_erb('nodejs <%= node_version %> (major: <%= node_major %>)') do |path|
        expect(described_class.new(path).render).to eq("nodejs #{node_version} (major: 26)")
      end
    end

    it 'leaves non-ERB content unchanged' do
      with_temp_erb("static content\n") do |path|
        expect(described_class.new(path).render).to eq("static content\n")
      end
    end
  end

  describe '.replace_marker_section' do
    let(:marker) { 'TEST_SECTION' }
    let(:original) do
      <<~MD
        before
        <!-- TEST_SECTION_START -->
        old content
        <!-- TEST_SECTION_END -->
        after
      MD
    end
    let(:result) { described_class.send(:replace_marker_section, original, marker, 'new content') }

    it 'replaces content between markers with the new content' do
      expect(result).to include('new content')
      expect(result).not_to include('old content')
      expect(result).to include('before')
      expect(result).to include('after')
    end

    it 'preserves the start and end marker tags' do
      expect(result).to include('<!-- TEST_SECTION_START -->')
      expect(result).to include('<!-- TEST_SECTION_END -->')
    end
  end

  describe '.process_all' do
    it 'generates output files from .erb templates and updates README markers' do
      Dir.mktmpdir do |dir|
        prepare_dir(dir)
        Dir.chdir(dir) do
          allow(described_class).to receive(:ruby_version).and_call_original
          stub_const('ErbProcessor::README_PATH', 'README.md')
          stub_const('ErbProcessor::README_SECTIONS',
                     { 'RUBY_PREREQUISITES' => 'documentation/ruby_prerequisites.md.erb' })

          described_class.process_all

          expect(File.read('sample.yml')).to eq("ruby: #{ruby_version}")
          expect(File.read('README.md')).to include("Ruby #{ruby_version} required")
          expect(File.read('README.md')).not_to include('old prereqs')
        end
      end
    end

    def prepare_dir(dir)
      File.write(File.join(dir, '.ruby-version'), "ruby-#{ruby_version}")
      File.write(File.join(dir, 'sample.yml.erb'), 'ruby: <%= ruby_version %>')
      File.write(File.join(dir, 'README.md'), readme_content)
      prereq_dir = File.join(dir, 'documentation')
      FileUtils.mkdir_p(prereq_dir)
      File.write(File.join(prereq_dir, 'ruby_prerequisites.md.erb'),
                 'Ruby <%= ruby_version %> required')
    end

    def readme_content
      <<~MD
        # Title
        <!-- RUBY_PREREQUISITES_START -->
        old prereqs
        <!-- RUBY_PREREQUISITES_END -->
      MD
    end
  end
end
