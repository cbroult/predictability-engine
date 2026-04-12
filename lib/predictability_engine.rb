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

  def self.run_report(file, format, output: nil, color: true, layout: nil)
    items = load_items(file)
    reports = Report.generate_all(items)

    if reports.size == 1 || format.to_sym == :terminal
      # For terminal or single report, just use the main one
      report = reports[:all]
      if %i[markdown md confluence conf].include?(format.to_sym)
        base = File.basename(file, '.*')
        report.generate_chart_images("reports/#{base}")
      end
      content = report.render(format.to_sym, layout: layout, color: color)
      if output || format.to_sym != :terminal
        write_report(file, format, content, output)
      else
        content
      end
    else
      # Multi-report generation (e.g. HTML dashboard with type-specific sub-dashboards)
      # We generate all reports and return a summary message
      last_msg = ''
      reports.each do |type, report|
        if %i[markdown md confluence conf].include?(format.to_sym)
          base = File.basename(file, '.*')
          report.generate_chart_images("reports/#{base}")
        end

        links = reports.keys.map do |t|
          label = (t == :all ? 'All' : t.to_s)
          url = (t == :all ? 'dashboard.html' : "#{t}.html")
          # If we are in a sub-report, the main dashboard is up one level
          url = "../#{url}" if type != :all && t == :all
          # If we are in the main dashboard, sub-reports are in 'types/'
          url = "types/#{url}" if type == :all && t != :all
          { label: label, url: url, active: (t == type) }
        end if format.to_sym == :html || format.to_sym == :landscape

        content = report.render(format.to_sym, layout: layout, color: color, sub_reports: links)
        last_msg = write_report(file, format, content, output, type: type)
      end
      "#{reports.size} reports generated. #{last_msg}"
    end
  end

  def self.write_report(file, format, content, output, type: :all)
    ext = format_to_ext(format.to_sym)
    base = File.basename(file, '.*')
    dir = "reports/#{base}"
    require 'fileutils'

    if type == :all
      FileUtils.mkdir_p(dir) unless output || File.exist?(dir)
      filename = case format.to_sym
                 when :html, :landscape, :dashboard then 'dashboard.html'
                 when :a3_landscape then 'dashboard_a3.pdf'
                 else "dashboard.#{ext}"
                 end
      output ||= File.join(dir, filename)
    else
      # Sub-report
      dir = File.join(dir, 'types')
      FileUtils.mkdir_p(dir)
      output = File.join(dir, "#{type}.#{ext}")
    end

    File.binwrite(output, content)
    "Report generated at #{output}"
  end

  def self.run_and_print_report(file, format, options, output: nil)
    puts run_report(file, format, output: output, color: options[:color],
                                  layout: options[:layout])
  end

  def self.format_to_ext(format)
    case format
    when :markdown, :md then 'md'
    when :confluence, :conf then 'conf'
    when :landscape, :dashboard then 'html'
    when :a3_landscape then 'pdf'
    when :ppt then 'pptx'
    else format.to_s
    end
  end

  private_class_method :format_to_ext
end
