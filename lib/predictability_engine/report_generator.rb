# frozen_string_literal: true

require 'fileutils'

module PredictabilityEngine
  # Logic for generating and writing reports.
  module ReportGenerator
    def self.run_report(file, format, **)
      items = PredictabilityEngine.load_items(file)
      reports = Report.generate_all(items)

      if reports.size == 1 || format.to_sym == :terminal
        generate_single_report(file, format, reports[:all], **)
      else
        generate_multi_reports(file, format, reports, **)
      end
    end

    def self.generate_single_report(file, format, report, **opts)
      fmt = format.to_sym
      generate_images_if_needed(file, fmt, report)

      content = report.render(fmt, **opts)
      if opts[:output] || fmt != :terminal
        write_report(file, format, content, opts[:output])
      else
        content
      end
    end

    def self.generate_multi_reports(file, format, reports, **opts)
      fmt = format.to_sym
      last_msg = ''
      reports.each do |type, report|
        generate_images_if_needed(file, fmt, report)
        links = build_nav_links(fmt, reports, type)
        content = report.render(fmt, sub_reports: links, **opts)
        last_msg = write_report(file, format, content, opts[:output], type: type)
      end
      "#{reports.size} reports generated. #{last_msg}"
    end

    def self.generate_images_if_needed(file, format, report)
      return unless %i[markdown md confluence conf].include?(format)

      base = File.basename(file, '.*')
      report.generate_chart_images("reports/#{base}")
    end

    def self.build_nav_links(format, reports, current_type)
      return unless %i[html landscape].include?(format)

      reports.keys.map do |t|
        url = nav_url(t, current_type)
        { label: (t == :all ? 'All' : t.to_s), url: url, active: (t == current_type) }
      end
    end

    def self.nav_url(type, current_type)
      url = (type == :all ? 'dashboard.html' : "#{type}.html")
      # If we are in a sub-report, the main dashboard is up one level
      url = "../#{url}" if current_type != :all && type == :all
      # If we are in the main dashboard, sub-reports are in 'types/'
      url = "types/#{url}" if current_type == :all && type != :all
      url
    end

    def self.write_report(file, format, content, output, type: :all)
      ext = format_to_ext(format.to_sym)
      base = File.basename(file, '.*')
      dir = "reports/#{base}"

      if type == :all
        FileUtils.mkdir_p(dir) unless output || File.exist?(dir)
        filename = dashboard_filename(format.to_sym, ext)
        output ||= File.join(dir, filename)
      else
        dir = File.join(dir, 'types')
        FileUtils.mkdir_p(dir)
        output = File.join(dir, "#{type}.#{ext}")
      end

      File.binwrite(output, content)
      "Report generated at #{output}"
    end

    def self.dashboard_filename(format, ext)
      case format
      when :html, :landscape, :dashboard then 'dashboard.html'
      when :a3_landscape then 'dashboard_a3.pdf'
      else "dashboard.#{ext}"
      end
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
  end
end
