# frozen_string_literal: true

require 'thor'
require 'tty-table'
require_relative 'visualizer'
require_relative 'summary_visualizer'

module PredictabilityEngine
  class Viz < Thor
    def self.exit_on_failure?
      true
    end

    class_option :color, type: :boolean, default: true, desc: 'Enable/disable color output for terminal charts'

    desc 'scatter FILE', 'Show Cycle Time scatter plot'
    def scatter(file)
      items = PredictabilityEngine.load_items(file)
      puts Visualizer.cycle_time_scatter(items, color: options[:color])
    end

    desc 'throughput FILE', 'Show Throughput histogram'
    def throughput(file)
      items = PredictabilityEngine.load_items(file)
      puts Visualizer.throughput_histogram(items, color: options[:color])
    end

    desc 'cfd FILE', 'Show Cumulative Flow Diagram'
    def cfd(file)
      items = PredictabilityEngine.load_items(file)
      puts Visualizer.cfd_plot(items, color: options[:color])
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

    desc 'forecasted_cfd FILE', 'Show Forecasted Cumulative Flow Diagram'
    def forecasted_cfd(file)
      items = PredictabilityEngine.load_items(file)
      puts Visualizer.forecasted_cfd_plot(items, color: options[:color])
    end

    desc 'html_forecasted_cfd FILE [OUTPUT]', 'Generate Vega-Lite HTML Forecasted CFD'
    def html_forecasted_cfd(file, output = nil)
      generate_html_chart(file, output, 'forecasted_cfd') do |items|
        Visualizer.vega_forecasted_cfd(items)
      end
    end

    desc 'all FILE', 'Show all terminal summary and visualizations'
    def all(file)
      puts PredictabilityEngine.run_report(file, :terminal, color: options[:color])
    end

    desc 'html_all FILE [OUTPUT]', 'Generate a combined HTML dashboard'
    def html_all(file, output = nil)
      puts PredictabilityEngine.run_report(file, :html, output: output)
    end

    desc 'all_html FILE [OUTPUT]', 'Alias for html_all'
    def all_html(file, output = nil)
      html_all(file, output)
    end

    private

    def generate_html_chart(file, output, type)
      items = PredictabilityEngine.load_items(file)
      output = generate_output_path(file, output, "#{type}.html")
      chart = yield(items)
      File.write(output, Visualizer.to_full_html(chart, items))
      puts "Chart generated at #{output}"
    end

    def generate_output_path(file, output, suffix)
      output || "#{File.basename(file, '.*')}_#{suffix}"
    end
  end

  class Cli < Thor
    def self.exit_on_failure?
      true
    end

    desc 'viz SUBCOMMAND ...ARGS', 'Visualization commands'
    subcommand 'viz', Viz
    desc 'summary FILE', 'Load data from FILE and show flow metrics summary'
    method_option :color, type: :boolean, default: true, desc: 'Enable/disable color output'
    def summary(file)
      items = PredictabilityEngine.load_items(file)
      puts SummaryVisualizer.metrics_terminal(items, color: options[:color])
    end

    desc 'report FILE FORMAT [OUTPUT]', 'Generate a full report in various formats (terminal, html, pdf, md, conf)'
    method_option :color, type: :boolean, default: true, desc: 'Enable/disable color output'
    def report(file, format = 'terminal', output = nil)
      puts PredictabilityEngine.run_report(file, format, output: output, color: options[:color])
    end

    desc 'forecast FILE BACKLOG_COUNT', 'Run Monte Carlo simulation for BACKLOG_COUNT items'
    def forecast(file, backlog_count)
      items = PredictabilityEngine.load_items(file)

      historical = Calculators::Throughput.daily(items).values
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
      # Assistant needs the manager or at least items.
      manager = DataManager.new
      manager.load(file)

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
