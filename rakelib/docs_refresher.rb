# frozen_string_literal: true

require 'open3'
require 'shellwords'

class DocsRefresher
  BLOCK_PATTERN = /<!-- run: (.+?) -->\n(```\w*\n)[\s\S]*?```\n<!-- end -->/
  ANSI_PATTERN  = /\e\[[0-9;]*[mK]/

  def initialize(content)
    @content = content
  end

  def refresh
    @content.gsub(BLOCK_PATTERN) do
      cmd   = Regexp.last_match(1).strip
      fence = Regexp.last_match(2)
      next Regexp.last_match(0) if cmd == 'skip'

      output = run_command(cmd)
      "<!-- run: #{cmd} -->\n#{fence}$ #{cmd}\n#{output}```\n<!-- end -->"
    end
  end

  private

  def run_command(cmd)
    args = build_args(cmd)
    output, status = Open3.capture2e(*args)
    raise "Command failed (exit #{status.exitstatus}): #{cmd}" unless status.success?

    output.gsub(ANSI_PATTERN, '')
  end

  def build_args(cmd)
    parts = Shellwords.split(cmd)
    parts.first == 'predictability-engine' ? ['bundle', 'exec', *parts] : parts
  end
end
