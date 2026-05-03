# frozen_string_literal: true

module PredictabilityEngine
  module TerminalVisualizer
    module CfdRenderer
      def self.build_forecast_params(data)
        start = data[:dates].first
        {
          start: start,
          x_coords: data[:dates].map { |d| (d - start).to_i },
          hist_size: data[:departed].size,
          total_items: data[:summary][:total_items],
          max_x: data[:dates].map { |d| (d - start).to_i }.max || 0,
          arrivals: data[:arrivals]
        }
      end

      def self.add_forecast_layers!(plot, data, params, percentiles)
        add_historical_departures!(plot, data, params)
        f_colors = { 50 => :yellow, 75 => :red, 85 => :magenta, 95 => :cyan, 98 => :white }
        percentiles.sort.reverse.each do |p|
          add_confidence_layer!(plot, data, params, p, sorted_pcts: percentiles.sort,
                                                       color: f_colors[p] || :white)
        end
      end

      def self.add_historical_departures!(plot, data, params)
        UnicodePlot.stairs!(plot, params[:x_coords].take(params[:hist_size]), data[:departed],
                            name: 'Departures', color: :green)
      end

      def self.add_confidence_layer!(plot, data, params, percentile, **opts)
        color = opts[:color]
        f_x = params[:x_coords].drop(params[:hist_size] - 1)
        f_y = data[:forecasts][percentile].drop(params[:hist_size] - 1)
        UnicodePlot.lineplot!(plot, f_x, f_y, name: "#{percentile}% Confidence", color: color)
        draw_deadline!(plot, data, params, percentile, opts[:sorted_pcts])
      end

      def self.draw_deadline!(plot, data, params, percentile, sorted_pcts)
        idx = sorted_pcts.index(percentile)
        target_p = idx < sorted_pcts.size - 1 ? sorted_pcts[idx + 1] : percentile
        deadline_idx = params[:hist_size] - 1 + data[:summary][:"p#{target_p}"]
        deadline_x = params[:x_coords][deadline_idx]
        forecast_at_deadline = data[:forecasts][percentile][deadline_idx]
        UnicodePlot.lineplot!(plot, [deadline_x, deadline_x], [0, forecast_at_deadline], color: :normal)
      end

      private_class_method :add_historical_departures!, :add_confidence_layer!, :draw_deadline!
    end
  end
end
