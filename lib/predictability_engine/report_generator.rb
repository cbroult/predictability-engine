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
      generate_images_if_needed(file, fmt, report, **opts)

      content = report.render(fmt, **opts)
      if opts[:output] || fmt != :terminal
        write_report(file, format, content, opts[:output], **opts)
      else
        content
      end
    end

    def self.generate_multi_reports(file, format, reports, **opts)
      fmt = format.to_sym
      last_msg = ''
      reports.each do |type, report|
        generate_images_if_needed(file, fmt, report, **opts)
        links = build_nav_links(fmt, reports, type)
        content = report.render(fmt, sub_reports: links, **opts)
        last_msg = write_report(file, format, content, opts[:output], type: type, **opts)
      end
      "#{reports.size} reports generated. #{last_msg}"
    end

    def self.generate_images_if_needed(file, format, report, **opts)
      return unless %i[markdown md confluence conf].include?(format)

      dir = report_dir(file, **opts)
      report.generate_chart_images(dir)
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

    def self.write_report(file, format, content, output, type: :all, **opts)
      ext = format_to_ext(format.to_sym)
      dir = report_dir(file, **opts)

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

    def self.report_dir(file, **opts)
      require 'pathname'
      base_dir = if opts[:output_dir]
                   opts[:output_dir]
                 else
                   input_dir = File.dirname(file)
                   input_dir == '.' ? 'reports' : File.join(input_dir, 'reports')
                 end
      Pathname.new(File.join(base_dir, File.basename(file, '.*'))).cleanpath.to_s
    end

    def self.clean_report_dir(file, **opts)
      dir = report_dir(file, **opts)
      FileUtils.rm_rf(dir) if File.exist?(dir)
    end

    def self.dashboard_filename(format, ext)
      case format
      when :html, :landscape, :dashboard then 'dashboard.html'
      when :a3_landscape then 'dashboard_a3.pdf'
      when :png then 'dashboard.png'
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
      when :png then 'png'
      else format.to_s
      end
    end
  end
end
