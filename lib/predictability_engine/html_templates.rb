# frozen_string_literal: true

module PredictabilityEngine
  HTML_HEADER = <<~HTML
    <head>
      <title>{{TITLE}}</title>
      <script src="https://cdn.jsdelivr.net/npm/vega@5"></script>
      <script src="https://cdn.jsdelivr.net/npm/vega-lite@5"></script>
      <script src="https://cdn.jsdelivr.net/npm/vega-embed@6"></script>
  HTML

  HTML_BASE = <<~HTML.freeze
    <!DOCTYPE html>
    <html>
    #{HTML_HEADER}
    {{STYLE}}
    </head>
    <body>
      {{BODY}}
    </body>
    </html>
  HTML

  HTML_LANDSCAPE_BODY = <<~HTML
    <header>
      <h1>{{TITLE}}</h1>
      <nav>{{NAV_BAR}}</nav>
      <div style="font-size: 0.8rem; color: #6c757d;">Generated: {{DATE}}</div>
    </header>
    <div class="dashboard-container">
      <div class="summary-panel">{{SUMMARY_CONTENT}}</div>
      {{CHART_PANELS}}
    </div>
    <script>
      function toggleFullscreen(btn) {
        var panel = btn.closest('.chart-panel');
        if (panel.classList.contains('fullscreen')) {
          panel.classList.remove('fullscreen');
          var bd = document.querySelector('.fullscreen-backdrop');
          if (bd) bd.remove();
          setTimeout(function() { window.dispatchEvent(new Event('resize')); }, 50);
        } else {
          var bd = document.createElement('div');
          bd.className = 'fullscreen-backdrop';
          bd.onclick = function() { toggleFullscreen(btn); };
          document.body.appendChild(bd);
          panel.classList.add('fullscreen');
          setTimeout(function() { window.dispatchEvent(new Event('resize')); }, 50);
        }
      }
      document.addEventListener('keydown', function(e) {
        if (e.key !== 'Escape') return;
        var fp = document.querySelector('.chart-panel.fullscreen');
        if (fp) toggleFullscreen(fp.querySelector('.chart-expand'));
      });
    </script>
  HTML

  private_constant :HTML_HEADER, :HTML_BASE, :HTML_LANDSCAPE_BODY
end
