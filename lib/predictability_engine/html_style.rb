# frozen_string_literal: true

module PredictabilityEngine
  HTML_BASE_STYLE = 'font-family: sans-serif; background: #f8f9fa;'

  HTML_STYLE_LANDSCAPE = <<~CSS.freeze
    <style>
      body { #{HTML_BASE_STYLE} margin: 0; padding: 15px; box-sizing: border-box; display: flex; flex-direction: column; background: #f4f7f6; }
      header { display: flex; justify-content: space-between; align-items: baseline; padding: 0 10px 10px 10px; border-bottom: 2px solid #e9ecef; margin-bottom: 15px; }
      h1 { margin: 0; font-size: 1.5rem; color: #2c3e50; font-weight: 700; }
      .nav-links { display: flex; gap: 10px; list-style: none; margin: 0; padding: 0; align-items: center; }
      .nav-links li { margin: 0; display: block; }
      .nav-links a { text-decoration: none; color: #3498db; font-size: 0.9rem; padding: 5px 12px; border-radius: 20px; border: 1.5px solid #3498db; font-weight: 600; transition: all 0.2s; }
      .nav-links a:hover { background: #3498db; color: white; }
      .nav-links a.active { background: #2c3e50; color: white; border-color: #2c3e50; cursor: default; }
      .nav-links li.nav-sep { color: #bbb; padding: 0 4px; user-select: none; }
      .dashboard-container { display: grid; grid-template-columns: 260px 1fr 1fr 1fr; grid-template-rows: 1fr 1fr; gap: 15px; flex-grow: 1; min-height: 0; min-width: 1300px; }
      .summary-panel { grid-row: span 2; background: white; padding: 20px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); overflow-y: auto; border: 1px solid #e9ecef; }
      .summary-panel h2 { font-size: 1.25rem; margin-top: 0; color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 8px; margin-bottom: 15px; }
      .summary-panel h3 { font-size: 1.1rem; color: #34495e; margin-top: 25px; border-bottom: 1px solid #eee; padding-bottom: 5px; }
      .chart-panel { background: white; padding: 15px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); display: flex; flex-direction: column; border: 1px solid #e9ecef; min-height: 280px; min-width: 0; }
      .panel-header { display: flex; align-items: center; gap: 6px; margin-bottom: 10px; }
      .panel-header h2 { margin: 0; flex-grow: 1; font-size: 1rem; color: #34495e; font-weight: 600; }
      .chart-container { flex-grow: 1; min-height: 0; width: 100%; overflow: hidden; display: flex; justify-content: center; align-items: center; }
      .chart-container > div { width: 100% !important; height: 100% !important; }
      ul { list-style: none; padding: 0; margin: 10px 0; }
      li { margin-bottom: 8px; font-size: 0.95rem; color: #505d6b; display: flex; flex-wrap: wrap; gap: 0 8px; }
      li strong { color: #2c3e50; white-space: nowrap; }
      .metric-value { margin-left: auto; text-align: right; }

      @media screen {
        body { height: 100vh; overflow: auto; }
      }

      @media print {
        body { height: auto; overflow: visible; padding: 5px; background: white; }
        .dashboard-container { grid-template-columns: 220px 1fr 1fr; gap: 10px; }
        .chart-panel, .summary-panel { box-shadow: none; border: 1px solid #eee; padding: 10px; }
        header { margin-bottom: 10px; padding-bottom: 5px; }
        h1 { font-size: 1.2rem; }
        .vega-bindings { display: none; }
        .chart-expand { display: none; }
      }

      .vega-bindings { font-size: 0.85rem; }
      .chart-expand { flex-shrink: 0; background: none; border: none; cursor: pointer; font-size: 1rem; color: #adb5bd; padding: 2px 4px; border-radius: 4px; line-height: 1; transition: color 0.2s, background 0.2s; }
      .chart-expand:hover { color: #2c3e50; background: rgba(0,0,0,0.06); }
      .chart-expand::before { content: '⛶'; }
      .chart-panel.fullscreen .chart-expand::before { content: '✕'; }
      .chart-panel.fullscreen { position: fixed; inset: 0; z-index: 1000; border-radius: 0; }
      .fullscreen-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.6); z-index: 999; }
      .vg-tooltip td { vertical-align: top !important; }
      .vg-tooltip td.value { white-space: pre-wrap !important; max-width: 250px !important; }

      li.breakdown { flex-direction: column; align-items: flex-start; }
      li.breakdown ul { list-style: none; padding: 0 0 0 10px; margin: 4px 0 0 0; }
      li.breakdown ul li { display: block; margin-bottom: 2px; justify-content: flex-start; }
    </style>
  CSS

  private_constant :HTML_BASE_STYLE, :HTML_STYLE_LANDSCAPE
end
