# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    module TooltipHelpers
      TOOLTIP_WRAP_WIDTH = 40

      def item_id_tooltip_field = { field: 'id', type: 'nominal', title: 'Work Item ID' }
      def title_tooltip_field = { field: 'title_display', type: 'nominal', title: 'Title' }
      def standard_item_tooltip_fields = [item_id_tooltip_field, title_tooltip_field]
      def item_href_and_tooltip(extra) = { href: url_href, tooltip: standard_item_tooltip_fields + extra }
      def url_href = { field: 'url', type: 'nominal' }

      def cycle_time_tooltip_field(field: 'cycle_time')
        { field: field, type: 'quantitative', title: 'Cycle Time (days)' }
      end

      def cfd_tooltip_fields
        [{ field: 'date', type: 'temporal', title: 'Date' }, { field: 'type', type: 'nominal', title: 'Type' },
         { field: 'count', type: 'quantitative', title: 'Items' }]
      end

      def wrap_tooltip_title(text, width: TOOLTIP_WRAP_WIDTH)
        str = text.to_s
        return str if str.length <= width

        str.split.each_with_object(['']) do |word, lines|
          lines << '' if "#{lines.last} #{word}".strip.length > width
          lines[-1] = "#{lines.last} #{word}".strip
        end.join("\n")
      end
    end
  end
end
