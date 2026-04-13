# frozen_string_literal: true

module PredictabilityEngine
  module Models
    class WorkItem
      attr_accessor :id, :title, :type, :start_date, :end_date

      def initialize(item_id:, title: nil, type: nil, start_date: nil, end_date: nil)
        @id = item_id
        @title = title
        @type = type
        @start_date = start_date ? Date.parse(start_date.to_s) : nil
        @end_date = end_date ? Date.parse(end_date.to_s) : nil
      end

      def cycle_time
        return nil unless completed?

        (@end_date - @start_date).to_i + 1 # Include both start and end days
      end

      def age(date = PredictabilityEngine.today)
        return nil if completed? || @start_date.nil?
        return 0 if date < @start_date

        (date - @start_date).to_i + 1
      end

      def completed?
        !@end_date.nil? && !@start_date.nil?
      end

      def in_progress?(date)
        return false unless @start_date
        return false if date < @start_date
        return true if @end_date.nil? || date < @end_date

        false
      end
    end
  end
end
