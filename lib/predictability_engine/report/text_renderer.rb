# frozen_string_literal: true

module PredictabilityEngine
  class Report
    module TextRenderer
      def self.render(report, fmt, color: false, layout: :standard, **)
        config = Constants::FORMAT_CONFIG[fmt]
        header = config[:h1].call(report.title)
        if layout.to_sym == :landscape
          return [header, '',
                  render_landscape(report, fmt, color: color, **)].join("\n")
        end

        [header, SummaryVisualizer.render(report.items, fmt, color: color, percentiles: report.percentiles),
         *Constants::CHART_CONFIG.map do |id, cfg|
           render_section(report, id, cfg, fmt, color: color, **)
         end].join("\n")
      end

      def self.render_landscape(report, fmt, color: false, **opts)
        sum = SummaryVisualizer.render(report.items, fmt, color: color, percentiles: report.percentiles)
        section_opts = opts.merge(color: color, table: true)
        ch = Constants::CHART_CONFIG.map { |id, c| render_section(report, id, c, fmt, section_opts) }
        br = fmt == :confluence ? ' \\\\ ' : '<br>'
        bold = fmt == :confluence ? '*' : '**'
        h_regex = fmt == :confluence ? /^h\d\.\s*(.*)$/ : /^#+\s*(.*)$/
        clean_sum = sum.gsub(h_regex, "#{bold}\\1#{bold}").gsub("\n\n", br).gsub("\n", br)
        clean_ch = ch.map { |c| c.gsub("\n", br) }

        build_table(fmt, clean_sum, clean_ch)
      end

      def self.build_table(fmt, sum, charts)
        rows = [
          ["| #{sum} | #{charts[0]} | #{charts[1]} |", "| | #{charts[2]} | #{charts[3]} |"],
          ["| #{sum} | #{charts[0]} | #{charts[1]} |", "| ^ | #{charts[2]} | #{charts[3]} |"]
        ]
        row_set = fmt == :markdown ? rows[0] : rows[1]
        md_hdr = "| | | |\n| :--- | :--- | :--- |"
        [(fmt == :markdown ? md_hdr : nil), *row_set].compact.join("\n")
      end

      def self.render_section(report, chart_id, cfg, fmt, options = {})
        title = section_title(cfg[:title], fmt, options[:table])
        if fmt != :terminal && image_available?(report, chart_id)
          [title, report.render_image_link(chart_id, fmt)].join("\n")
        elsif %i[markdown confluence].include?(fmt) && MermaidVisualizer.respond_to?(chart_id)
          render_mermaid(report, chart_id, fmt, title)
        else
          render_ascii(report, chart_id, Constants::FORMAT_CONFIG[fmt], options[:color], title,
                       **options.except(:color, :table))
        end
      end

      def self.section_title(title, fmt, table)
        bold = fmt == :confluence ? '*' : '**'
        table ? "#{bold}#{title}#{bold}" : Constants::FORMAT_CONFIG[fmt][:h2].call(title)
      end

      def self.image_available?(report, chart_id)
        report.images_path && File.exist?(File.join(report.images_path, "#{chart_id}.png"))
      end

      def self.render_mermaid(report, chart_id, fmt, title)
        wrap = fmt == :confluence ? ['{mermaid}', '{mermaid}'] : ['```mermaid', '```']
        [title, wrap[0], MermaidVisualizer.send(chart_id, report.items, percentiles: report.percentiles),
         wrap[1], render_legend(chart_id, report.percentiles)].compact.join("\n")
      end

      def self.render_ascii(report, chart_id, config, color, title, **opts) # rubocop:disable Metrics/ParameterLists
        call_opts = opts.merge(percentiles: report.percentiles, color: color || false)
        [title, config[:code].call(title, TerminalVisualizer.send(chart_id, report.items, **call_opts))].join("\n")
      end

      def self.render_legend(chart_id, pcts)
        return nil unless chart_id == :forecasted_cfd_plot

        "\n**Legend:** Arrivals (blue), Departures (green), Projections (various colors). " \
          "Vertical lines for: #{pcts.join('%, ')}% confidence."
      end

      private_class_method :render_landscape, :build_table, :render_section, :section_title,
                           :image_available?, :render_mermaid, :render_ascii, :render_legend
    end
  end
end
