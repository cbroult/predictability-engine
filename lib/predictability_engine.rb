# frozen_string_literal: true

require 'active_support/all'
require 'zeitwerk'
require 'csv'
require 'dotenv'
require 'json'
require 'langchain'

Dotenv.load

loader = Zeitwerk::Loader.for_gem
loader.setup

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

  def self.run_and_print_report(file, format, options, output: nil)
    opts = options.to_h.symbolize_keys.merge(output: output)
    puts run_report(file, format, **opts)
  end
end
