# frozen_string_literal: true

require_relative '../report'

module PredictabilityEngine
  class Report
    module ImageGenerator
      def self.generate(report, base_dir)
        images_path = File.join(base_dir, 'images')
        FileUtils.mkdir_p(images_path)
        temp_html = "tmp/images_#{report.object_id}.html"
        File.write(temp_html, report.render_html(layout: :standard))

        require 'playwright'
        Playwright.create(playwright_cli_executable_path: report.playwright_bin) do |playwright|
          playwright.chromium.launch(**report.playwright_chromium_launch_opts) do |browser|
            page = browser.new_page(viewport: { width: 800, height: 600 })
            page.goto("file://#{File.expand_path(temp_html)}")
            sleep 2
            Constants::CHART_CONFIG.each_key { |id| capture_chart(page, id, images_path) }
          end
        end
        images_path
      ensure
        FileUtils.rm_f(temp_html) if temp_html
      end

      def self.capture_chart(page, chart_id, images_path)
        title = Constants::CHART_CONFIG[chart_id][:title]
        page.locator(".chart-panel:has(h2:text-is(\"#{title}\"))")
            .screenshot(path: File.join(images_path, "#{chart_id}.png"))
      end
    end
  end
end
