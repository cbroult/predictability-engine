# frozen_string_literal: true

require 'fileutils'

module PredictabilityEngine
  # Logic for generating and writing reports.
  module ReportGenerator # rubocop:disable Metrics/ModuleLength
    def self.run_report(file, format, items: nil, **)
      items ||= PredictabilityEngine.load_items(file)
      reports = Report.generate_all(items)

      if facet_total(reports).zero? || format.to_sym == :terminal
        generate_single_report(file, format, reports[:all], **)
      else
        generate_multi_reports(file, format, reports, **)
      end
    end

    def self.facet_total(reports)
      Report::FACETS.sum { |f| (reports[f[:key]] || {}).size }
    end

    def self.each_facet_entry(reports)
      yield :all, reports[:all]
      Report::FACETS.each do |facet|
        (reports[facet[:key]] || {}).each { |value, report| yield [facet[:key], value], report }
      end
    end

    def self.generate_single_report(file, format, report, **opts)
      fmt = format.to_sym
      generate_images_if_needed(file, fmt, report, **opts)
      opts = opts.merge(sub_reports: export_links_for(:all)) if html_format?(fmt) && !opts[:sub_reports]

      content = report.render(fmt, **opts)
      if opts[:output] || fmt != :terminal
        write_report(file, format, content, opts[:output], **opts)
      else
        content
      end
    end

    def self.generate_multi_reports(file, format, reports, **opts)
      fmt = format.to_sym
      msgs = []
      each_facet_entry(reports) do |slot, report|
        generate_images_if_needed(file, fmt, report, **opts)
        links = build_nav_links(fmt, reports, slot)
        content = report.render(fmt, sub_reports: links, **opts)
        msgs << write_report(file, format, content, opts[:output], slot: slot, **opts)
      end
      "#{msgs.size} reports generated:\n#{msgs.join("\n")}"
    end

    def self.generate_images_if_needed(file, format, report, **)
      return unless %i[markdown md confluence conf].include?(format)

      dir = report_dir(file, **)
      report.generate_chart_images(dir)
    rescue StandardError => e
      PredictabilityEngine.logger.warn { "Chart image generation failed: #{e.message}. Inline images will be omitted." }
    end

    def self.build_nav_links(format, reports, current_slot)
      return unless html_format?(format)

      links = [nav_entry(:all, current_slot, label: 'All')]
      Report::FACETS.each do |facet|
        values = (reports[facet[:key]] || {}).keys
        next if values.empty?

        links << { separator: true }
        values.each { |value| links << nav_entry([facet[:key], value], current_slot, label: value) }
      end
      links + export_links_for(current_slot)
    end

    def self.html_format?(format)
      %i[html landscape].include?(format)
    end

    def self.export_links_for(slot)
      prefix = slot.is_a?(Array) ? '../' : ''
      [{ label: 'CSV', url: "#{prefix}dashboard.csv", download: true },
       { label: 'XLSX', url: "#{prefix}dashboard.xlsx", download: true }]
    end

    def self.nav_entry(slot, current_slot, label:)
      { label: label, url: nav_url(slot, current_slot), active: slot == current_slot }
    end

    def self.nav_url(slot, current_slot)
      return main_dashboard_url(current_slot) if slot == :all

      target_facet_key, value = slot
      target_dir = facet_dirname(target_facet_key)
      return "#{value}.html" if current_slot.is_a?(Array) && current_slot[0] == target_facet_key
      return "../#{target_dir}/#{value}.html" if current_slot.is_a?(Array)

      "#{target_dir}/#{value}.html"
    end

    def self.main_dashboard_url(current_slot)
      current_slot.is_a?(Array) ? '../dashboard.html' : 'dashboard.html'
    end

    def self.facet_dirname(facet_key)
      Report::FACETS.find { |f| f[:key] == facet_key }[:dirname]
    end

    def self.write_report(file, format, content, output, slot: :all, **) # rubocop:disable Metrics/ParameterLists
      ext = format_to_ext(format.to_sym)
      dir = report_dir(file, **)

      if slot == :all
        FileUtils.mkdir_p(dir) unless output || File.exist?(dir)
        output ||= File.join(dir, dashboard_filename(format.to_sym, ext))
      else
        facet_key, value = slot
        dir = File.join(dir, facet_dirname(facet_key))
        FileUtils.mkdir_p(dir)
        output = File.join(dir, "#{value}.#{ext}")
      end

      File.binwrite(output, content)
      "Report generated at #{output}"
    end

    def self.report_dir(file, **opts)
      base_dir = if opts[:output_dir]
                   opts[:output_dir]
                 else
                   input_dir = File.dirname(file)
                   input_dir == '.' ? 'reports' : File.join(input_dir, 'reports')
                 end
      Pathname.new(File.join(base_dir, File.basename(file, '.*'))).cleanpath.to_s
    end

    def self.clean_report_dir(file, **)
      dir = report_dir(file, **)
      FileUtils.rm_rf(dir)
    end

    def self.dashboard_filename(format, ext)
      case format
      when :html, :landscape, :dashboard then 'dashboard.html'
      when :a3_landscape then 'dashboard_a3.pdf'
      when :png then 'dashboard.png'
      else "dashboard.#{ext}"
      end
    end

    FORMAT_TO_EXT = {
      markdown: 'md', md: 'md',
      confluence: 'conf', conf: 'conf',
      landscape: 'html', dashboard: 'html',
      a3_landscape: 'pdf',
      ppt: 'pptx',
      png: 'png',
      raw_csv: 'csv',
      xlsx: 'xlsx'
    }.freeze

    def self.format_to_ext(format)
      FORMAT_TO_EXT[format] || format.to_s
    end
  end
end
