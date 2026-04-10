# frozen_string_literal: true

require 'thor'
require 'tty-table'
require_relative 'visualizer'

module PredictabilityEngine
  class Viz < Thor
    def self.exit_on_failure?
      true
    end

    desc 'scatter FILE', 'Show Cycle Time scatter plot'
    def scatter(file)
      manager = DataManager.new
      manager.load_csv(file)
      puts Visualizer.cycle_time_scatter(manager.work_items)
    end

    desc 'throughput FILE', 'Show Throughput histogram'
    def throughput(file)
      manager = DataManager.new
      manager.load_csv(file)
      puts Visualizer.throughput_histogram(manager.work_items)
    end

    desc 'cfd FILE', 'Show Cumulative Flow Diagram'
    def cfd(file)
      manager = DataManager.new
      manager.load_csv(file)
      puts Visualizer.cfd_plot(manager.work_items)
    end

    desc 'html_scatter FILE [OUTPUT]', 'Generate Vega-Lite HTML scatter plot'
    def html_scatter(file, output = nil)
      generate_html_chart(file, output, 'scatter') do |items|
        Visualizer.vega_cycle_time_scatter(items)
      end
    end

    desc 'html_throughput FILE [OUTPUT]', 'Generate Vega-Lite HTML throughput histogram'
    def html_throughput(file, output = nil)
      generate_html_chart(file, output, 'throughput') do |items|
        Visualizer.vega_throughput_histogram(items)
      end
    end

    desc 'html_cfd FILE [OUTPUT]', 'Generate Vega-Lite HTML CFD'
    def html_cfd(file, output = nil)
      generate_html_chart(file, output, 'cfd') do |items|
        Visualizer.vega_cfd(items)
      end
    end

    desc 'all FILE', 'Show all terminal summary and visualizations'
    def all(file)
      manager = DataManager.new
      manager.load_csv(file)
      items = manager.work_items
      puts Visualizer.summary_metrics_terminal(items)
      puts '=== Cycle Time Scatter Plot ==='
      puts Visualizer.cycle_time_scatter(items)
      puts "\n=== Throughput Histogram ==="
      puts Visualizer.throughput_histogram(items)
      puts "\n=== Cumulative Flow Diagram ==="
      puts Visualizer.cfd_plot(items)
    end

    desc 'html_all FILE [OUTPUT]', 'Generate a combined HTML dashboard'
    def html_all(file, output = nil)
      manager = DataManager.new
      manager.load_csv(file)
      output ||= "#{File.basename(file, '.*')}_dashboard.html"
      chart = Visualizer.vega_dashboard(manager.work_items)
      File.write(output, Visualizer.to_full_html(chart, manager.work_items))
      puts "Dashboard generated at #{output}"
    end

    desc 'all_html FILE [OUTPUT]', 'Alias for html_all'
    def all_html(file, output = nil)
      html_all(file, output)
    end

    private

    def generate_html_chart(file, output, type)
      manager = DataManager.new
      manager.load_csv(file)
      output ||= "#{File.basename(file, '.*')}_#{type}.html"
      chart = yield(manager.work_items)
      File.write(output, Visualizer.to_full_html(chart, manager.work_items))
      puts "Chart generated at #{output}"
    end
  end

  class Cli < Thor
    def self.exit_on_failure?
      true
    end

    desc 'viz SUBCOMMAND ...ARGS', 'Visualization commands'
    subcommand 'viz', Viz
    desc 'summary FILE', 'Load data from FILE and show flow metrics summary'
    def summary(file)
      manager = DataManager.new
      manager.load_csv(file)
      puts Visualizer.summary_metrics_terminal(manager.work_items)
    end

    desc 'forecast FILE BACKLOG_COUNT', 'Run Monte Carlo simulation for BACKLOG_COUNT items'
    def forecast(file, backlog_count)
      manager = DataManager.new
      manager.load_csv(file)

      historical = Calculators::Throughput.daily(manager.work_items).values
      results = Simulators::MonteCarlo.when_will_it_be_done(backlog_count.to_i, historical)

      print_forecast_results(backlog_count, results)
    end

    private

    def print_forecast_results(backlog_count, results)
      puts 'Monte Carlo Simulation Results (When will it be done?)'
      puts '------------------------------------------------------'
      puts "Backlog size: #{backlog_count}"
      puts "Number of trials: #{Simulators::MonteCarlo::DEFAULT_TRIALS}"
      puts ''
      puts 'Results:'
      [50, 85, 95].each do |p|
        val = Simulators::MonteCarlo.percentile(results, p)
        puts "  #{p}% confidence: Done in #{val} days"
      end
    end

    public

    desc 'ask FILE QUESTION', 'Ask the AI assistant about the data in FILE'
    def ask(file, question)
      manager = DataManager.new
      manager.load_csv(file)

      assistant = Agents::Assistant.new(manager)
      puts 'AI Thinking...'
      response = assistant.ask(question)

      # response is an array of messages or similar depending on langchain version
      # In recent langchainrb versions assistant.run returns the last message
      puts 'AI Response:'
      puts '------------'
      # Assuming response is a message object with .content
      if response.respond_to?(:content)
        puts response.content
      else
        puts response
      end
    end
  end
end
