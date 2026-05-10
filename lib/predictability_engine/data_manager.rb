# frozen_string_literal: true

module PredictabilityEngine
  class DataManager
    attr_reader :work_items, :source

    def initialize
      @work_items = []
      @source = nil
    end

    def load(spec, **)
      @source = spec
      @work_items = DataSources::Factory.for(spec, **).load(spec)
    end

    # Backward compatibility
    alias load_csv load

    def completed_items
      @work_items.select(&:completed?)
    end

    def active_items
      @work_items.reject(&:completed?)
    end
  end
end
