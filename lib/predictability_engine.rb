# frozen_string_literal: true

require 'active_support/all'
require 'zeitwerk'
require 'csv'
require 'dotenv'
require 'json'
require 'langchain'

Dotenv.load

require_relative 'predictability_engine/logger'

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/predictability_engine/logger.rb") # Manual require
loader.setup

# Auto-inject SemanticLogger::Loggable into every class/module defined under
# PredictabilityEngine:: so each gains its own named `logger` / `self.logger`
# without polluting Object.
TracePoint.new(:end) do |tp|
  mod = tp.self
  next unless mod.is_a?(Module)
  next unless mod.name&.start_with?('PredictabilityEngine::')
  next if mod.ancestors.include?(SemanticLogger::Loggable)

  mod.include(SemanticLogger::Loggable)
end.enable

module PredictabilityEngine
  class Error < StandardError; end
  DEFAULT_PERCENTILES = [50, 75, 85, 95, 98].freeze

  def self.completed_items(items)
    items.select(&:completed?)
  end

  def self.active_items(items)
    items.reject(&:completed?)
  end

  def self.today
    ENV['MOCK_TODAY'] ? Date.parse(ENV['MOCK_TODAY']) : Date.current
  end

  def self.cycle_time_percentile(items, percentile)
    Calculators::CycleTime.percentile(items, percentile)
  end

  def self.mapped_percentiles(work_items, percentiles = DEFAULT_PERCENTILES)
    percentiles.map do |p|
      val = cycle_time_percentile(work_items, p)
      { val: val, label: "#{p}% Percentile", p: p } if val
    end.compact
  end

  def self.load_items(spec)
    manager = DataManager.new
    manager.load(spec)
    manager.work_items
  end

  def self.run_report(file, format, **)
    ReportGenerator.run_report(file, format, **)
  end

  def self.write_report(input_file, format, content, output, type: :all)
    ReportGenerator.write_report(input_file, format, content, output, type: type)
  end

  def self.run_and_print_report(file, format, options, output: nil, items: nil)
    opts = options.to_h.symbolize_keys.merge(output: output)
    message = run_report(file, format, items: items, **opts)
    logger.info { message }
  end

  def self.format_date(date)
    return nil unless date

    date.to_date.to_s
  end

  def self.format_year_week(date)
    return nil unless date

    date.to_date.strftime('%G-W%V')
  end

  def self.format_year_month(date)
    return nil unless date

    date.to_date.strftime('%Y-%m')
  end

  def self.format_datetime(time)
    return nil unless time

    time.to_time.strftime('%Y-%m-%d %H:%M')
  end

  def self.write_file(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def self.sample_data_path(name = 'sample_data.csv')
    path = File.join(File.expand_path('..', __dir__), 'data', 'samples', name)
    raise Error, "Sample data not found: #{path}" unless File.exist?(path)

    path
  end
end
