# frozen_string_literal: true

module PredictabilityEngine
  module Loggable
    def logger
      PredictabilityEngine.logger
    end

    module ClassMethods
      def logger
        PredictabilityEngine.logger
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end
end
