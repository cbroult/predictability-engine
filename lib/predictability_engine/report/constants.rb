# frozen_string_literal: true

module PredictabilityEngine
  class Report
    module Constants
      PRIORITY_ORDER = %w[Highest High Medium Low Lowest].freeze

      CHART_CONFIG = {
        aging_wip: { title: 'Aging Work In Progress' },
        forecasted_cfd_plot: { title: 'Forecasted Cumulative Flow Diagram', vega: :forecasted_cfd },
        cfd_plot: { title: 'Cumulative Flow Diagram', vega: :cfd },
        cycle_time_scatter: { title: 'Cycle Time Scatter Plot' },
        throughput_histogram: { title: 'Throughput Histogram' },
        cycle_time_bands: { title: 'Cycle Time Bands Over Time' }
      }.freeze

      FORMAT_CONFIG = {
        terminal: { h1: ->(t) { "=== #{t} ===" }, h2: ->(t) { "\n=== #{t} ===" },
                    code: ->(_t, c) { c }, aliases: %i[console ascii], layout: :standard },
        markdown: { h1: ->(t) { "# #{t}\n" }, h2: ->(t) { "\n## #{t}" },
                    code: ->(_t, c) { "```\n#{c}\n```" }, aliases: [:md], layout: :standard },
        confluence: { h1: ->(t) { "h1. #{t}\n" }, h2: ->(t) { "\nh2. #{t}" },
                      code: ->(t, c) { "{code:title=#{t}}\n#{c}\n{code}" }, aliases: [:conf], layout: :standard },
        html: { layout: :landscape },
        pdf: { layout: :landscape },
        png: { layout: :landscape },
        ppt: { layout: :landscape },
        landscape: { aliases: [:dashboard], layout: :landscape },
        a3_landscape: { format: 'A3', landscape: true, layout: :landscape },
        raw_csv: {},
        xlsx: {}
      }.freeze

      FONT_PATHS = [
        '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
        '/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf',
        '/usr/share/fonts/TTF/DejaVuSansMono.ttf',
        '/System/Library/Fonts/Supplemental/Courier New.ttf',
        '/Library/Fonts/Courier New.ttf',
        'C:/Windows/Fonts/cour.ttf'
      ].freeze

      FONT_BOLD_PATHS = [
        '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf',
        '/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf',
        '/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf',
        '/System/Library/Fonts/Supplemental/Courier New Bold.ttf',
        '/Library/Fonts/Courier New Bold.ttf',
        'C:/Windows/Fonts/courbd.ttf'
      ].freeze

      RESOLUTION_CONFIG = {
        '5k' => [5120, 2880],
        '4k' => [3840, 2160],
        'hd' => [1920, 1080],
        'a0' => [7680, 5432],
        'a1' => [5432, 3838],
        'a2' => [3838, 2713],
        'a3' => [2713, 1918],
        'a4' => [1918, 1356],
        'a5' => [1356, 956],
        'a6' => [956, 678]
      }.freeze

      DEFAULT_SIZE = 'a4'
      DEFAULT_FORECAST_HISTORY = '4w'
      DEFAULT_HISTORICAL_RANGE = 'all'
    end
  end
end
