# frozen_string_literal: true

module PredictabilityEngine
  class DataManager
    attr_reader :work_items

    def initialize
      @work_items = []
    end

    def load(spec)
      @work_items = DataSources::Factory.for(spec).load(spec)
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
