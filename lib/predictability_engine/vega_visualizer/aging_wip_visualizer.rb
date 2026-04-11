# frozen_string_literal: true

module PredictabilityEngine
  module VegaVisualizer
    module AgingWipVisualizer
      def self.aging_wip(work_items, title: 'Aging Work In Progress',
                         percentiles: PredictabilityEngine::DEFAULT_PERCENTILES, **_opts)
        data = Calculators::Aging.item_age_data(work_items)
        return Vega.lite.data([]).title(title || 'Aging Work In Progress') if data.empty?

        pcts = PredictabilityEngine.mapped_percentiles(work_items, percentiles)
        VegaVisualizer.apply_standard_dims(
          Vega.lite.data(data)
              .layer([aging_bar_layer, *aging_rule_layers(pcts)]),
          title: title
        )
      end

      def self.aging_bar_layer
        { mark: { type: 'bar', tooltip: true, stroke: 'white', strokeWidth: 0.2 },
          encoding: { x: { field: 'id', type: 'nominal', title: 'Work Item ID', sort: '-y',
                           axis: { labelAngle: -45, labelOverlap: 'parity' } },
                      y: { field: 'age', type: 'quantitative', title: 'Age (days)' },
                      color: { field: 'age', type: 'quantitative', scale: { scheme: 'yelloworangered' },
                               legend: { orient: 'bottom', title: 'Age' } } } }
      end

      def self.aging_rule_layers(pcts)
        pcts.map do |p|
          { data: { values: [{ val: p[:val] }] },
            mark: { type: 'rule', strokeDash: [4, 4] },
            encoding: { y: { field: 'val', type: 'quantitative' },
                        color: { value: '#e45756' } } }
        end
      end
    end
  end
end
