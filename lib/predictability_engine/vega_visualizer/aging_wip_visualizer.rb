# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    module AgingWipVisualizer
      def self.aging_wip(items, title: 'Aging Work In Progress',
                         pcts: PredictabilityEngine::DEFAULT_PERCENTILES, **)
        data = Calculators::Aging.item_age_data(items)
        return Vega.lite.data([]).title(title || 'Aging Work In Progress') if data.empty?

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
                      tooltip: [VegaVisualizer.item_id_tooltip_field,
                                { field: 'title', type: 'nominal', title: 'Title' },
                                { field: 'age', type: 'quantitative', title: 'Age (days)' }] } }
      end

      def self.aging_rule_layers(mapped_pcts)
        mapped_pcts.map do |p|
          { data: { values: [{ val: p[:val] }] },
            mark: { type: 'rule', strokeDash: [4, 4] },
            encoding: { y: VegaVisualizer.quantitative_y_axis('val'), color: { value: '#e45756' } } }
        end
      end
    end
  end
end
