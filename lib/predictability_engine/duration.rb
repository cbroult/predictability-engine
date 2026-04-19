# frozen_string_literal: true

module PredictabilityEngine
  module Duration
    UNITS = { 'd' => 1, 'w' => 7, 'm' => 30 }.freeze

    def self.parse(spec)
      return nil if spec.nil?

      match = spec.to_s.strip.downcase.match(/\A(\d+)([dwm])\z/)
      raise ArgumentError, "Invalid duration #{spec.inspect} (expected e.g. 1w, 2m, 30d)" unless match

      match[1].to_i * UNITS.fetch(match[2])
    end
  end
end
