# frozen_string_literal: true

require 'csv'

module PredictabilityEngine
  module DataGenerator
    PRESETS = {
      small: { completed: 10, wip: 4 },
      medium: { completed: 40, wip: 10 },
      large: { completed: 150, wip: 50 },
      xl: { completed: 4000, wip: 400 }
    }.freeze

    def self.generate(output:, size: :medium, completed: nil, wip: nil)
      File.write(output, content(size: size, completed: completed, wip: wip))
      output
    end

    def self.content(size: :medium, completed: nil, wip: nil)
      preset = PRESETS.fetch(size.to_sym) do
        raise ArgumentError, "Unknown size: #{size} (available: #{PRESETS.keys.join(', ')})"
      end
      build_csv(completed || preset[:completed], wip || preset[:wip])
    end

    def self.build_csv(completed_count, wip_count)
      today = PredictabilityEngine.today
      CSV.generate do |csv|
        csv << %w[id title start_date end_date]
        write_completed(csv, completed_count, today)
        write_wip(csv, completed_count, wip_count, today)
      end
    end

    def self.write_completed(csv, count, today)
      (1..count).each do |i|
        start_date = today - rand(200..400)
        end_date   = start_date + rand(5..30)
        csv << ["PROJ-#{i}", "Task #{i}",
                PredictabilityEngine.format_date(start_date),
                PredictabilityEngine.format_date(end_date)]
      end
    end

    def self.write_wip(csv, offset, count, today)
      ((offset + 1)..(offset + count)).each do |i|
        start_date = today - rand(1..100)
        csv << ["PROJ-#{i}", "In Progress Task #{i}",
                PredictabilityEngine.format_date(start_date), nil]
      end
    end
  end
end
