# frozen_string_literal: true

require 'thor'
require 'tty-table'
require 'fileutils'
require_relative 'visualizer'
require_relative 'summary_visualizer'

module PredictabilityEngine
  class Viz < Thor
    def self.exit_on_failure?
      true
    end

    class_option :color, type: :boolean, default: true, desc: 'Enable/disable color output for terminal charts'

    desc 'scatter SOURCE', 'Show Cycle Time scatter plot'
    def scatter(source)
      items = PredictabilityEngine.load_items(source)
      puts Visualizer.cycle_time_scatter(items, color: options[:color])
    end

    desc 'throughput SOURCE', 'Show Throughput histogram'
    def throughput(source)
      items = PredictabilityEngine.load_items(source)
      puts Visualizer.throughput_histogram(items, color: options[:color])
    end

    desc 'cfd SOURCE', 'Show Cumulative Flow Diagram'
    def cfd(source)
      items = PredictabilityEngine.load_items(source)
      puts Visualizer.cfd_plot(items, color: options[:color])
    end

    desc 'aging_wip SOURCE', 'Show Aging Work In Progress'
    def aging_wip(source)
      items = PredictabilityEngine.load_items(source)
      puts Visualizer.aging_wip(items, color: options[:color])
    end

    desc 'html_scatter SOURCE [OUTPUT]', 'Generate Vega-Lite HTML scatter plot'
    def html_scatter(source, output = nil)
      generate_html_chart(source, output, 'scatter') do |items|
        Visualizer.vega_cycle_time_scatter(items)
      end
    end

    desc 'html_throughput SOURCE [OUTPUT]', 'Generate Vega-Lite HTML throughput histogram'
    def html_throughput(source, output = nil)
      generate_html_chart(source, output, 'throughput') do |items|
        Visualizer.vega_throughput_histogram(items)
      end
    end

    desc 'html_cfd SOURCE [OUTPUT]', 'Generate Vega-Lite HTML CFD'
    def html_cfd(source, output = nil)
      generate_html_chart(source, output, 'cfd') do |items|
        Visualizer.vega_cfd(items)
      end
    end

    desc 'forecasted_cfd SOURCE', 'Show Forecasted Cumulative Flow Diagram'
    def forecasted_cfd(source)
      items = PredictabilityEngine.load_items(source)
      puts Visualizer.forecasted_cfd_plot(items, color: options[:color])
    end

    desc 'html_forecasted_cfd SOURCE [OUTPUT]', 'Generate Vega-Lite HTML Forecasted CFD'
    def html_forecasted_cfd(source, output = nil)
      generate_html_chart(source, output, 'forecasted_cfd') do |items|
        Visualizer.vega_forecasted_cfd(items)
      end
    end

    desc 'html_aging_wip SOURCE [OUTPUT]', 'Generate Vega-Lite HTML Aging WIP'
    def html_aging_wip(source, output = nil)
      generate_html_chart(source, output, 'aging_wip') do |items|
        Visualizer.vega_aging_wip(items)
      end
    end

    desc 'all SOURCE', 'Show all terminal summary and visualizations'
    def all(source)
      run_and_print_report(source, :terminal)
    end

    desc 'html_all SOURCE [OUTPUT]', 'Generate a combined HTML dashboard (landscape)'
    def html_all(source, output = nil)
      run_and_print_report(source, :html, output: output)
    end

    desc 'landscape SOURCE [OUTPUT]', 'Alias for html_all'
    def landscape(source, output = nil)
      run_and_print_report(source, :landscape, output: output)
    end

    desc 'dashboard SOURCE [OUTPUT]', 'Alias for landscape'
    def dashboard(source, output = nil)
      landscape(source, output)
    end

    desc 'all_html SOURCE [OUTPUT]', 'Alias for html_all'
    def all_html(source, output = nil)
      html_all(source, output)
    end

    desc 'pdf SOURCE [OUTPUT]', 'Generate a PDF report'
    def pdf(source, output = nil)
      run_and_print_report(source, :pdf, output: output)
    end

    desc 'a3_landscape SOURCE [OUTPUT]', 'Generate an A3 landscape PDF dashboard'
    def a3_landscape(source, output = nil)
      run_and_print_report(source, :a3_landscape, output: output)
    end

    desc 'markdown SOURCE [OUTPUT]', 'Generate a Markdown report'
    def markdown(source, output = nil)
      run_and_print_report(source, :markdown, output: output)
    end

    desc 'md SOURCE [OUTPUT]', 'Alias for markdown'
    def md(source, output = nil)
      markdown(source, output)
    end

    desc 'confluence SOURCE [OUTPUT]', 'Generate a Confluence markup report'
    def confluence(source, output = nil)
      run_and_print_report(source, :confluence, output: output)
    end

    desc 'conf SOURCE [OUTPUT]', 'Alias for confluence'
    def conf(source, output = nil)
      confluence(source, output)
    end

    desc 'all_formats SOURCE', 'Generate all report formats at once'
    def all_formats(source)
      %i[terminal html pdf md conf a3_landscape ppt].each do |fmt|
        PredictabilityEngine.run_and_print_report(source, fmt, options)
      rescue StandardError => e
        warn "Failed to generate #{fmt} report: #{e.message}"
      end
    end

    private

    def run_and_print_report(source, format, output: nil)
      PredictabilityEngine.run_and_print_report(source, format, options, output: output)
    end

    def generate_html_chart(source, output, type)
      items = PredictabilityEngine.load_items(source)
      path = generate_output_path(source, output, "#{type}.html")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, Visualizer.to_full_html(yield(items), items))
      puts "Chart generated at #{path}"
    end

    def generate_output_path(source, output, filename)
      return output if output

      base = File.basename(source, '.*')
      File.join('reports', base, filename)
    end
  end

  class Cli < Thor
    def self.exit_on_failure?
      true
    end

    desc 'viz SUBCOMMAND ...ARGS', 'Visualization commands'
    subcommand 'viz', Viz
    desc 'summary SOURCE', 'Load data from SOURCE and show flow metrics summary'
    method_option :color, type: :boolean, default: true, desc: 'Enable/disable color output'
    def summary(source)
      items = PredictabilityEngine.load_items(source)
      puts SummaryVisualizer.metrics_terminal(items, color: options[:color])
    end

    desc 'report SOURCE FORMAT [OUTPUT]', 'Generate a full report in various formats (terminal, html, pdf, md, conf)'
    method_option :color, type: :boolean, default: true, desc: 'Enable/disable color output'
    def report(input_source, format = 'terminal', output = nil)
      PredictabilityEngine.run_and_print_report(input_source, format, options, output: output)
    end

    desc 'batch SOURCE', 'Run all report formats for the given SOURCE'
    method_option :color, type: :boolean, default: true, desc: 'Enable/disable color output'
    def batch(source)
      Viz.new([], options).all_formats(source)
    end

    desc 'init FILENAME', 'Create a template YAML file for JIRA source'
    def init(filename)
      filename += '.yml' unless filename.end_with?('.yml', '.yaml')
      content = <<~YAML
        # JIRA Data Source Configuration
        # jira_profile: prod-instance # Optional: profile name from ~/.config/jira/jira_credentials.yml
        # project: MYPROJ            # Optional: JIRA Project Key
        # filter_id: "12345"         # Optional: JIRA Filter ID
        # filter_name: "My Filter"   # Optional: JIRA Filter Name
        # query: "project = PROJ"    # Optional: Direct JQL query
      YAML
      File.write(filename, content)
      puts "Template created at #{filename}"
    end

    desc 'jira_config PROFILE', 'Generate/Update JIRA credentials in ~/.config/jira/jira_credentials.yml'
    def jira_config(profile)
      site = ask('Jira site (e.g., https://your-domain.atlassian.net):')
      email = ask('Jira email:')
      token = ask('Jira API token:', echo: false)
      puts '' # newline after hidden token input

      path = Config::JIRA_CREDENTIALS_FILE
      FileUtils.mkdir_p(File.dirname(path))

      config = File.exist?(path) ? YAML.load_file(path) : {}
      config ||= {}
      config['profiles'] ||= {}
      config['profiles'][profile] = {
        'site' => site,
        'email' => email,
        'token' => token
      }

      File.write(path, config.to_yaml)
      puts "Jira credentials for profile '#{profile}' saved to #{path}"
    end

    desc 'forecast SOURCE BACKLOG_COUNT', 'Run Monte Carlo simulation for BACKLOG_COUNT items'
    def forecast(source, backlog_count)
      items = PredictabilityEngine.load_items(source)

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
      PredictabilityEngine::DEFAULT_PERCENTILES.each do |p|
        val = Simulators::MonteCarlo.percentile(results, p)
        puts "  #{p}% confidence: Done in #{val} days"
      end
    end

    public

    desc 'ask_ai SOURCE QUESTION', 'Ask the AI assistant about the data in SOURCE'
    def ask_ai(source, question)
      # Assistant needs the manager or at least items.
      manager = DataManager.new
      manager.load(source)

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
