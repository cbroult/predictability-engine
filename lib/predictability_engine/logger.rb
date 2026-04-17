# frozen_string_literal: true

require 'logger'
require 'json'
require 'fileutils'

module PredictabilityEngine
  class Logger
    def self.instance
      @instance ||= new
    end

    def initialize
      @level = ::Logger::INFO
      @log_file = nil
      @console_logger = create_console_logger
      @file_logger = nil
    end

    def setup(level: 'info', log_file: nil)
      @level = parse_level(level)
      @log_file = log_file
      @console_logger.level = @level
      if log_file
        FileUtils.mkdir_p(File.dirname(log_file))
        @file_logger = create_file_logger(log_file)
        @file_logger.level = @level
      end
    end

    def info(msg)
      @console_logger.info(msg)
      @file_logger&.info(msg)
    end

    def warn(msg)
      @console_logger.warn(msg)
      @file_logger&.warn(msg)
    end

    def error(msg)
      @console_logger.error(msg)
      @file_logger&.error(msg)
    end

    def debug(msg)
      @console_logger.debug(msg)
      @file_logger&.debug(msg)
    end

    private

    def parse_level(level)
      case level.to_s.downcase
      when 'debug' then ::Logger::DEBUG
      when 'info'  then ::Logger::INFO
      when 'warn'  then ::Logger::WARN
      when 'error' then ::Logger::ERROR
      else ::Logger::INFO
      end
    end

    def create_console_logger
      logger = ::Logger.new($stdout)
      logger.formatter = proc do |severity, _datetime, _progname, msg|
        case severity
        when 'ERROR' then "\e[31mError: #{msg}\e[0m\n"
        when 'WARN'  then "\e[33mWarning: #{msg}\e[0m\n"
        when 'DEBUG' then "\e[90mDEBUG: #{msg}\e[0m\n"
        else "#{msg}\n"
        end
      end
      logger
    end

    def create_file_logger(path)
      # Daily rotation, keep 7 files
      logger = ::Logger.new(path, 'daily', 7)
      logger.formatter = proc do |severity, datetime, _progname, msg|
        # Strip ANSI colors for machine-readable file log
        clean_msg = msg.to_s.gsub(/\e\[([;\d]+)?m/, '')
        {
          timestamp: datetime.iso8601,
          level: severity,
          message: clean_msg
        }.to_json + "\n"
      end
      logger
    end
  end

  def self.logger
    Logger.instance
  end

  def self.setup_logging(level: 'info', log_file: nil)
    Logger.instance.setup(level: level, log_file: log_file)
  end
end
