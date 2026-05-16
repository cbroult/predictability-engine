# frozen_string_literal: true

require 'spec_helper'
require_relative '../../rakelib/docs_refresher'

RSpec.describe DocsRefresher do
  subject(:refresher) { described_class.new(content) }

  def marker_block(cmd, body: "stale output\n", lang: 'shell')
    <<~MD
      <!-- run: #{cmd} -->
      ```#{lang}
      $ #{cmd}
      #{body}```
      <!-- end -->
    MD
  end

  describe '#refresh' do
    context 'with no markers' do
      let(:content) { "# Title\n\nSome text with a code block:\n\n```ruby\nx = 1\n```\n" }

      it 'returns the content unchanged' do
        expect(refresher.refresh).to eq(content)
      end
    end

    context 'with a run: skip marker' do
      let(:content) do
        <<~MD
          Before.

          <!-- run: skip -->
          ```shell
          $ some-live-jira-command --profile prod
          live output that must not be replaced
          ```
          <!-- end -->

          After.
        MD
      end

      it 'leaves the block body unchanged' do
        expect(refresher.refresh).to include('live output that must not be replaced')
      end

      it 'preserves the markers and fence tags' do
        result = refresher.refresh
        expect(result).to include('<!-- run: skip -->')
        expect(result).to include('<!-- end -->')
        expect(result).to include('```shell')
      end
    end

    context 'with a runnable marker' do
      let(:content) { marker_block('echo hello') }

      it 'replaces the stale body with fresh command output' do
        result = refresher.refresh
        expect(result).to include('hello')
        expect(result).not_to include('stale output')
      end

      it 'preserves the opening marker' do
        expect(refresher.refresh).to include('<!-- run: echo hello -->')
      end

      it 'preserves the closing marker' do
        expect(refresher.refresh).to include('<!-- end -->')
      end

      it 'preserves the fence language tag' do
        expect(refresher.refresh).to include('```shell')
      end

      it 'keeps the prompt line matching the marker command' do
        expect(refresher.refresh).to include('$ echo hello')
      end
    end

    context 'when command output contains ANSI escape codes' do
      let(:content) { marker_block('echo colored', body: "stale\n") }

      before do
        allow(Open3).to receive(:capture2e)
          .with('echo', 'colored')
          .and_return(["\e[1mBold\e[0m and \e[36mcyan\e[0m\n", instance_double(Process::Status, success?: true)])
      end

      it 'strips ANSI codes from the captured output' do
        result = refresher.refresh
        expect(result).to include('Bold and cyan')
        expect(result).not_to match(/\e\[/)
      end
    end

    context 'with a predictability-engine command' do
      let(:content) { marker_block('predictability-engine help', body: "old help output\n") }

      it 'runs it via bundle exec' do
        allow(Open3).to receive(:capture2e)
          .with('bundle', 'exec', 'predictability-engine', 'help')
          .and_return(["Commands: ...\n", instance_double(Process::Status, success?: true)])
        refresher.refresh
        expect(Open3).to have_received(:capture2e)
          .with('bundle', 'exec', 'predictability-engine', 'help')
      end
    end

    context 'when the command exits non-zero' do
      let(:content) { marker_block('false', body: "old output\n") }

      it 'raises an error mentioning the command' do
        expect { refresher.refresh }.to raise_error(RuntimeError, /false/)
      end
    end

    context 'with multiple markers in one document' do
      let(:content) do
        <<~MD
          # Doc

          #{marker_block('echo first', body: "stale first\n")}
          Middle paragraph.

          <!-- run: skip -->
          ```shell
          $ live-jira-command
          live output
          ```
          <!-- end -->

          #{marker_block('echo second', body: "stale second\n", lang: 'text')}
        MD
      end

      it 'refreshes all runnable blocks' do
        result = refresher.refresh
        expect(result).to include('first')
        expect(result).to include('second')
      end

      it 'does not touch skip blocks' do
        expect(refresher.refresh).to include('live output')
      end

      it 'removes stale content from refreshed blocks' do
        result = refresher.refresh
        expect(result).not_to include('stale first')
        expect(result).not_to include('stale second')
      end

      it 'preserves prose between blocks' do
        expect(refresher.refresh).to include('Middle paragraph.')
      end
    end
  end
end
