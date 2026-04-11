# frozen_string_literal: true

require 'redcarpet'
markdown = File.read('reports/sample_data/report.md')

# Custom renderer for Mermaid
class MermaidRenderer < Redcarpet::Render::HTML
  def block_code(code, language)
    if language == 'mermaid'
      "<div class=\"mermaid\">\n#{code}\n</div>"
    else
      "<pre><code class=\"language-#{language}\">#{code}</code></pre>"
    end
  end
end

renderer = MermaidRenderer.new
html_content = Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, tables: true).render(markdown)

full_html = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <title>Markdown Render Verification</title>
    <script type="module">
      import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
      mermaid.initialize({ startOnLoad: true, theme: 'neutral' });
    </script>
    <style>
      body { font-family: sans-serif; margin: 40px; line-height: 1.6; max-width: 1200px; margin: auto; }
      pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
      .mermaid { margin: 20px 0; background: white; border: 1px solid #ddd; padding: 10px; }
      table { border-collapse: collapse; width: 100%; }
      th, td { border: 1px solid #ddd; padding: 12px; text-align: left; vertical-align: top; }
      img { max-width: 100%; height: auto; }
    </style>
  </head>
  <body>
    #{html_content}
  </body>
  </html>
HTML

File.write('reports/sample_data/md_verify.html', full_html)
puts 'MD verification file updated at reports/sample_data/md_verify.html'
