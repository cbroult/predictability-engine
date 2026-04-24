# frozen_string_literal: true

require 'semantic_logger'
require 'fileutils'

module PredictabilityEngine
  # Custom console formatter matching current terminal output:
  #   INFO  → plain message (no prefix)
  #   WARN  → yellow "Warning: …"
  #   ERROR → red    "Error: …"
  #   DEBUG → gray   "DEBUG: …"
  class TerminalFormatter < SemanticLogger::Formatters::Base
    def call(log, _logger)
      msg = log.message.to_s
      case log.level
      when :error then "\e[31mError: #{msg}\e[0m\n"
      when :warn  then "\e[33mWarning: #{msg}\e[0m\n"
      when :debug then "\e[90mDEBUG: #{msg}\e[0m\n"
      else "#{msg}\n"
      end
    end
  end

  # Called from CliBase#initialize via --log-level / --log-file options.
  # Removes only appenders previously added by this method (tracked in
  # @_pe_appenders) so that external appenders — e.g. test StringIO captures —
  # are never disturbed.
  def self.setup_logging(level: 'info', log_file: nil)
    SemanticLogger.default_level = level.to_sym
    (@_pe_appenders || []).each { |a| SemanticLogger.remove_appender(a) }
    @_pe_appenders = []
    @_pe_appenders << SemanticLogger.add_appender(io: $stdout, formatter: TerminalFormatter.new)
    return unless log_file

    FileUtils.mkdir_p(File.dirname(log_file))
    @_pe_appenders << SemanticLogger.add_appender(file_name: log_file, formatter: :json)
  end

  # Module-level logger named "PredictabilityEngine".
  # Memoized so that all call sites share the same instance (required for RSpec
  # `receive` mocks, and avoids allocating a new object on every log call).
  def self.logger
    @logger ||= SemanticLogger[self]
  end
end
