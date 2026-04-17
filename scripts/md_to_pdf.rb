#!/usr/bin/env ruby
# frozen_string_literal: true

require 'redcarpet'
require 'playwright'
require 'fileutils'
require 'optparse'
require 'cgi'

# Script to convert Markdown with Mermaid diagrams to PDF
class MdToPdf
  def initialize(md_path, pdf_path)
    @md_path = md_path
    @pdf_path = pdf_path
    @temp_html = "tmp/md_to_pdf_#{Process.pid}.html"
  end

  def run
    content = File.read(@md_path)
    html = render_to_html(content)
    FileUtils.mkdir_p('tmp')
    File.write(@temp_html, html)
    generate_pdf
  ensure
    FileUtils.rm_f(@temp_html)
  end

  private

  def render_to_html(content)
    renderer = Redcarpet::Render::HTML.new(with_toc_data: true)
    markdown = Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, tables: true)
    rendered_md = markdown.render(content)

    mermaid_blocks = content.scan(/```mermaid\n(.+?)\n```/m).flatten
    # Process mermaid blocks to div.mermaid
    # Redcarpet gives <pre><code class="mermaid">...</code></pre>
    processed_md = rendered_md.gsub(%r{<pre><code class="mermaid">(.+?)</code></pre>}m) do
      "<div class=\"mermaid\">\n#{CGI.unescapeHTML(::Regexp.last_match(1)).strip}\n</div>"
    end

    separate_pages = mermaid_blocks.each_with_index.map do |code, index|
      <<~HTML
        <div class="page separate">
          <h1>Visual Diagram #{index + 1}</h1>
          <div class="mermaid">
            #{code.strip}
          </div>
        </div>
      HTML
    end.join("\n")

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
        <style>
          @page { size: A4 landscape; margin: 0; }
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; margin: 0; line-height: 1.6; }
          .page { page-break-after: always; width: 297mm; height: 210mm; padding: 20mm; box-sizing: border-box; }
          .integrated { font-size: 14px; }
          .separate { display: flex; flex-direction: column; align-items: center; justify-content: center; }
          .mermaid { margin: 20px auto; max-width: 100%; }
          .separate .mermaid { transform: scale(1.5); }
          h1 { border-bottom: 1px solid #eee; padding-bottom: 10px; }
          pre { background: #f6f8fa; padding: 16px; border-radius: 6px; overflow: auto; }
          blockquote { border-left: 4px solid #dfe2e5; color: #6a737d; padding: 0 1em; margin: 0; }
        </style>
      </head>
      <body>
        <div class="page integrated">
          #{processed_md}
        </div>
        #{separate_pages}
        <script>
          mermaid.initialize({ startOnLoad: true, theme: 'default', securityLevel: 'loose' });
        </script>
      </body>
      </html>
    HTML
  end

  def generate_pdf
    # Use playwright_bin from PredictabilityEngine if available or use a default
    # But for a standalone script, we can just use the gem's default or common path
    playwright_bin = ENV['PLAYWRIGHT_CLI_EXECUTABLE_PATH'] || `which playwright`.strip
    playwright_bin = nil if playwright_bin.empty?

    Playwright.create(playwright_cli_executable_path: playwright_bin) do |p|
      p.chromium.launch do |browser|
        page = browser.new_page(viewport: { width: 1280, height: 720 })
        page.goto("file://#{File.expand_path(@temp_html)}")
        sleep 2 # Wait for mermaid to render
        page.pdf(path: @pdf_path, format: 'A4', landscape: true, printBackground: true)
      end
    end
  end
end

options = {
  input: 'documentation/pitch.md',
  output: 'pitch.pdf'
}

OptionParser.new do |opts|
  opts.banner = 'Usage: md_to_pdf.rb [options]'
  opts.on('-i', '--input FILE', 'Input Markdown file') { |v| options[:input] = v }
  opts.on('-o', '--output FILE', 'Output PDF file') { |v| options[:output] = v }
end.parse!

MdToPdf.new(options[:input], options[:output]).run
puts "Generated PDF from #{options[:input]} to #{options[:output]}"
