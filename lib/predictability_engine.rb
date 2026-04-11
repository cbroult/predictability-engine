# frozen_string_literal: true

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

  def self.cycle_time_percentile(items, percentile)
    Calculators::CycleTime.percentile(items, percentile)
  end

  def self.load_items(spec)
    manager = DataManager.new
    manager.load(spec)
    manager.work_items
  end

  def self.run_report(file, format, output: nil, color: true)
    items = load_items(file)
    report = Report.generate_all(items)
    content = report.render(format.to_sym, color: color)

    if output || format.to_sym != :terminal
      ext = format_to_ext(format.to_sym)
      suffix = format.to_sym == :html ? "_all.#{ext}" : "_report.#{ext}"
      output ||= "#{File.basename(file, '.*')}#{suffix}"
      File.binwrite(output, content)
      "Dashboard generated at #{output}"
    else
      content
    end
  end

  def self.format_to_ext(format)
    case format
    when :markdown, :md then 'md'
    when :confluence, :conf then 'conf'
    else format.to_s
    end
  end

  private_class_method :format_to_ext
end
