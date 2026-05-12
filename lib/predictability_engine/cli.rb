# frozen_string_literal: true

require 'thor'
require 'tty-table'
require 'fileutils'
require_relative 'visualizer'
require_relative 'summary_visualizer'

module PredictabilityEngine
  # Shared Thor configuration for Cli and Viz: common class_options plus
  # auto-wiring of PredictabilityEngine.setup_logging from --log-level/--log-file.
  module CliBase
    VALID_SIZES = Report::Constants::RESOLUTION_CONFIG.keys.freeze
    SIZE_DESC = "Image size for PNG/PPT reports (#{VALID_SIZES.join(', ')})".freeze

    def self.included(base)
      base.extend(ClassMethods)
      base.class_option :output_dir, type: :string, desc: 'Output directory for reports'
      base.class_option :size, type: :string, default: Report::Constants::DEFAULT_SIZE,
                               enum: VALID_SIZES, desc: SIZE_DESC
      base.class_option :log_level, type: :string, default: 'info',
                                    desc: 'Logging level (debug, info, warn, error)'
      base.class_option :log_file, type: :string, desc: 'Log file path'
      base.class_option :url_prefix, type: :string,
                                     desc: 'URL prefix for constructing item URLs from IDs (e.g. https://jira.example.com/browse/)'
    end

    module ClassMethods
      def exit_on_failure?
        true
      end
    end

    def initialize(*args)
      super
      PredictabilityEngine.setup_logging(level: options[:log_level], log_file: options[:log_file])
    end
  end

  class Viz < Thor
    include CliBase

    class_option :color, type: :boolean, default: true, desc: 'Enable/disable color output for terminal charts'

    { scatter: [:cycle_time_scatter, 'Show Cycle Time scatter plot'],
      throughput: [:throughput_histogram, 'Show Throughput histogram'],
      cfd: [:cfd_plot, 'Show Cumulative Flow Diagram'],
      aging_wip: [:aging_wip, 'Show Aging Work In Progress'],
      forecasted_cfd: [:forecasted_cfd_plot,
                       'Show Forecasted Cumulative Flow Diagram'] }.each do |cmd, (viz_method, description)|
      desc "#{cmd} SOURCE", description
      define_method(cmd) do |source|
        items = PredictabilityEngine.load_items(source)
        PredictabilityEngine.logger.info Visualizer.send(viz_method, items, color: options[:color])
      end
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
    method_option :historical_cfd_history, type: :string,
                                           desc: 'Historical CFD window (e.g. 1w, 2m, 30d; default: full range)'
    def html_cfd(source, output = nil)
      generate_html_chart(source, output, 'cfd') do |items|
        Visualizer.vega_cfd(items, history_range: options[:historical_cfd_history])
      end
    end

    desc 'html_forecasted_cfd SOURCE [OUTPUT]', 'Generate Vega-Lite HTML Forecasted CFD'
    method_option :forecast_history, type: :string,
                                     desc: 'Forecasted CFD history window (e.g. 1w, 2m, 30d; default: 2m)'
    def html_forecasted_cfd(source, output = nil)
      generate_html_chart(source, output, 'forecasted_cfd') do |items|
        Visualizer.vega_forecasted_cfd(items, history_range: options[:forecast_history])
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

    desc 'png SOURCE [OUTPUT]', 'Generate a PNG report'
    def png(source, output = nil)
      run_and_print_report(source, :png, output: output)
    end

    desc 'all_formats SOURCE', 'Generate all report formats at once'
    def all_formats(source)
      ReportGenerator.clean_report_dir(source, **options)
      items   = PredictabilityEngine.load_items(source, url_prefix: options[:url_prefix])
      reports = Report.generate_all(items)
      %i[terminal html pdf png md conf ppt raw_csv xlsx].each do |fmt|
        PredictabilityEngine.run_and_print_report(source, fmt, options, items: items, reports: reports)
      rescue StandardError => e
        PredictabilityEngine.logger.warn { "Failed to generate #{fmt} report: #{e.message}" }
      end
    end

    private

    def run_and_print_report(source, format, output: nil)
      PredictabilityEngine.run_and_print_report(source, format, options, output: output)
    end

    def generate_html_chart(source, output, type)
      items = PredictabilityEngine.load_items(source)
      path = generate_output_path(source, output, "#{type}.html")
      PredictabilityEngine.write_file(path, Visualizer.to_full_html(yield(items), items))
      PredictabilityEngine.logger.info { "Chart generated at #{path}" }
    end

    def generate_output_path(source, output, filename)
      return output if output

      base = File.basename(source, '.*')
      dir = if options[:output_dir]
              File.join(options[:output_dir], base)
            else
              File.join(File.dirname(source), 'reports', base)
            end
      File.join(dir, filename)
    end
  end

  class Cli < Thor
    include CliBase
    include JiraConfigPrompter

    desc 'viz SUBCOMMAND ...ARGS', 'Visualization commands'
    subcommand 'viz', Viz
    desc 'summary SOURCE', 'Load data from SOURCE and show flow metrics summary'
    method_option :color, type: :boolean, default: true, desc: 'Enable/disable color output'
    def summary(source)
      items = PredictabilityEngine.load_items(source)
      PredictabilityEngine.logger.info { SummaryVisualizer.metrics_terminal(items, color: options[:color]) }
    end

    desc 'report SOURCE FORMAT [OUTPUT]', 'Generate a full report in various formats (terminal, html, pdf, md, conf)'
    method_option :color, type: :boolean, default: true, desc: 'Enable/disable color output'
    method_option :clean, type: :boolean, default: true, desc: 'Clean the report directory before generation'
    def report(input_source, format = 'terminal', output = nil)
      if format.to_sym != :terminal && output.nil? && options[:clean]
        ReportGenerator.clean_report_dir(input_source, **options)
      end
      PredictabilityEngine.run_and_print_report(input_source, format, options, output: output)
    end

    desc 'batch SOURCE', 'Run all report formats for the given SOURCE'
    method_option :color, type: :boolean, default: true, desc: 'Enable/disable color output'
    def batch(source)
      Viz.new([], options).all_formats(source)
    end

    desc 'setup', 'Install/update all dependencies (Ruby gems + Node.js + Playwright + Chromium)'
    def setup
      SetupManager.new.run
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
      PredictabilityEngine.logger.info { "Template created at #{filename}" }
    end

    desc 'jira_config PROFILE', 'Generate/Update JIRA credentials in ~/.config/jira/jira_credentials.yml'
    method_option :auth_mode, aliases: '-a', default: 'basic',
                              desc: 'Auth mode: basic | bearer | cookie | mfa_api | mfa_browser'
    def jira_config(profile)
      site = ask('Jira site (e.g., https://your-domain.atlassian.net):')
      context_path = ask('Context path, if any (e.g., /jira — leave blank for Atlassian Cloud):')
      mode = options[:auth_mode]

      profile_data = build_profile_data(site, context_path, mode)

      path = Config.jira_credentials_file
      FileUtils.mkdir_p(File.dirname(path))

      config = File.exist?(path) ? YAML.load_file(path) : {}
      config ||= {}
      config['profiles'] ||= {}
      config['profiles'][profile] = profile_data

      File.write(path, config.to_yaml)
      PredictabilityEngine.logger.info { "Jira credentials for profile '#{profile}' saved to #{path}" }
    end

    desc 'jira_workflow PROFILE [OUTPUT]',
         'Extract Jira workflow statuses for PROFILE into an editable YAML mapping ' \
         '(default: ~/.config/jira/<profile>.workflow.yml). Re-running refreshes the ' \
         'snapshot while preserving any roles you already set.'
    def jira_workflow(profile, output = nil)
      path = output || JiraWorkflow.default_path(profile)
      fresh = JiraWorkflow.extract(profile)
      workflow = File.exist?(path) ? JiraWorkflow.load(path).refresh(fresh) : fresh
      workflow.write(path)
      action = File.exist?(path) ? 'refreshed' : 'written'
      PredictabilityEngine.logger.info { "Workflow for profile '#{profile}' #{action}: #{path}" }
      PredictabilityEngine.logger.info { "Review #{path} and set role: arrival / departure / null per status." }
    end

    desc 'jira_workflow_merge OUTPUT SOURCE1 [SOURCE2 ...]',
         'Merge multiple workflow configs into a shared config. Each SOURCE is ' \
         'either a profile name (resolved to ~/.config/jira/<profile>.workflow.yml) ' \
         'or an explicit path to a workflow YAML file.'
    def jira_workflow_merge(output, *sources)
      raise Error, 'Need at least one workflow source to merge' if sources.empty?

      configs = sources.map do |src|
        path = File.exist?(src) ? src : JiraWorkflow.default_path(src)
        JiraWorkflow.load(path) || raise(Error, "Workflow not found for '#{src}' (tried #{path})")
      end
      JiraWorkflow.merge(configs).write(output)
      PredictabilityEngine.logger.info { "Merged workflow from #{sources.join(', ')} written to #{output}" }
    end

    desc 'forecast SOURCE BACKLOG_COUNT', 'Run Monte Carlo simulation for BACKLOG_COUNT items'
    def forecast(source, backlog_count)
      items = PredictabilityEngine.load_items(source)

      historical = Calculators::Throughput.daily(items).values
      results = Simulators::MonteCarlo.when_will_it_be_done(backlog_count.to_i, historical)

      print_forecast_results(backlog_count, results)
    end

    desc 'calibrate SOURCE', 'Validate Monte Carlo simulation accuracy via hindcast calibration'
    method_option :validation_trials, type: :numeric, default: 200,
                                      desc: 'Number of historical as-of dates to sample'
    method_option :primary_trials, type: :numeric, default: 10_000,
                                   desc: 'Monte Carlo trials per hindcast point'
    def calibrate(source)
      items = PredictabilityEngine.load_items(source)
      result = Simulators::MonteCarloValidator.calibration(
        items,
        validation_trials: options[:validation_trials],
        primary_trials: options[:primary_trials]
      )
      if result.nil?
        PredictabilityEngine.logger.info do
          'Insufficient data for hindcast calibration (need 10+ completed items with historical WIP).'
        end
        return
      end
      print_calibration_results(result)
    end

    GENERATE_SIZE_DESC = "Preset volume: #{DataGenerator::PRESETS.map do |n, c|
      "#{n} (#{c[:completed]}/#{c[:wip]})"
    end.join(', ')}".freeze

    desc 'generate OUTPUT', 'Generate a synthetic sample CSV for smoke tests and demos'
    method_option :size, type: :string, default: 'medium',
                         enum: DataGenerator::PRESETS.keys.map(&:to_s),
                         desc: GENERATE_SIZE_DESC
    method_option :completed, type: :numeric, desc: 'Override number of completed items'
    method_option :wip, type: :numeric, desc: 'Override number of WIP items'
    def generate(output)
      path = DataGenerator.generate(
        output: output,
        size: options[:size].to_sym,
        completed: options[:completed],
        wip: options[:wip]
      )
      PredictabilityEngine.logger.info { "Synthetic #{options[:size]} dataset written to #{path}" }
    end

    private

    def ask_secret(prompt)
      if $stdin.isatty
        result = ask(prompt, echo: false)
        puts ''
        result
      else
        ask(prompt)
      end
    end

    def print_calibration_results(result)
      PredictabilityEngine.logger.info { 'Monte Carlo Hindcast Calibration' }
      PredictabilityEngine.logger.info { '---------------------------------' }
      PredictabilityEngine.logger.info { "Trials run: #{result[:trials_run]} / Skipped: #{result[:trials_skipped]}" }
      PredictabilityEngine.logger.info { '' }
      PredictabilityEngine::DEFAULT_PERCENTILES.each do |p|
        coverage = result[p]
        next unless coverage

        actual_pct = (coverage * 100).round(1)
        delta = (coverage - (p / 100.0)) * 100
        label = if delta > 2 then 'conservative'
                elsif delta < -2 then 'optimistic'
                else 'well-calibrated'
                end
        PredictabilityEngine.logger.info { "  p#{p}: #{actual_pct}% actual coverage  (#{label})" }
      end
    end

    def print_forecast_results(backlog_count, results)
      PredictabilityEngine.logger.info { 'Monte Carlo Simulation Results (When will it be done?)' }
      PredictabilityEngine.logger.info { '------------------------------------------------------' }
      PredictabilityEngine.logger.info { "Backlog size: #{backlog_count}" }
      PredictabilityEngine.logger.info { "Number of trials: #{Simulators::MonteCarlo::DEFAULT_TRIALS}" }
      PredictabilityEngine.logger.info { '' }
      PredictabilityEngine.logger.info { 'Results:' }
      PredictabilityEngine::DEFAULT_PERCENTILES.each do |p|
        val = Simulators::MonteCarlo.percentile(results, p)
        PredictabilityEngine.logger.info { "  #{p}% confidence: Done in #{val} days" }
      end
    end

    public

    desc 'ask_ai SOURCE QUESTION', 'Ask the AI assistant about the data in SOURCE'
    def ask_ai(source, question)
      # Assistant needs the manager or at least items.
      manager = DataManager.new
      manager.load(source)

      assistant = Agents::Assistant.new(manager)
      PredictabilityEngine.logger.info { 'AI Thinking...' }
      response = assistant.ask(question)

      # response is an array of messages or similar depending on langchain version
      # In recent langchainrb versions assistant.run returns the last message
      PredictabilityEngine.logger.info { 'AI Response:' }
      PredictabilityEngine.logger.info { '------------' }
      # Assuming response is a message object with .content
      if response.respond_to?(:content)
        PredictabilityEngine.logger.info { response.content }
      else
        PredictabilityEngine.logger.info { response }
      end
    end
  end
end
