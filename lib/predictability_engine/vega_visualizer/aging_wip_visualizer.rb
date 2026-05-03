# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    module AgingWipVisualizer
      def self.aging_wip(items, title: 'Aging Work In Progress',
                         pcts: PredictabilityEngine::DEFAULT_PERCENTILES, **)
        raw = Calculators::Aging.item_age_data(items)
        return Vega.lite.data([]).title(title || 'Aging Work In Progress') if raw.empty?

        data = raw.map { |row| row.merge(title_display: VegaVisualizer.wrap_tooltip_title(row[:title].to_s)) }
        mapped = PredictabilityEngine.mapped_percentiles(items, pcts)
        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(data)
              .layer([aging_bar_layer, *aging_rule_layers(mapped)]),
          title: title
        )
      end

      def self.aging_bar_layer
        { mark: { type: 'bar', stroke: 'white', strokeWidth: 0.2 },
          encoding: { x: { field: 'id', type: 'nominal', title: 'Work Item ID', sort: '-y',
                           axis: { labelAngle: -45, labelOverlap: 'parity' } },
                      y: VegaVisualizer.quantitative_y_axis('age', title: 'Age (days)'),
                      color: { field: 'age', type: 'quantitative', scale: { scheme: 'yelloworangered' },
                               legend: { orient: 'bottom', title: 'Age' } },
                      **VegaVisualizer.item_href_and_tooltip(
                        [{ field: 'age', type: 'quantitative', title: 'Age (days)' }]
                      ) } }
      end

      def self.aging_rule_layers(mapped_pcts)
        mapped_pcts.map do |p|
          { data: { values: [{ val: p[:val], label: p[:label] }] },
            mark: { type: 'rule', strokeDash: [4, 4] },
            encoding: { y: VegaVisualizer.quantitative_y_axis('val', title: 'Age (days)'),
                        color: { value: '#e45756' },
                        tooltip: [{ field: 'label', type: 'nominal', title: 'Percentile' },
                                  { field: 'val', type: 'quantitative', title: 'Age (days)' }] } }
        end
      end
    end
  end
end
