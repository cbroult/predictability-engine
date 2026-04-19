# frozen_string_literal: true

# Provision and seed the three PE test projects across dev/wp/gha environments.
#
# Usage:
#   JIRA_SITE=https://acme.atlassian.net JIRA_EMAIL=you@acme.com JIRA_API_TOKEN=... \
#     ruby scripts/jira_project_setup.rb setup   [--env dev] [--count 25] [--profile default]
#     ruby scripts/jira_project_setup.rb teardown [--env dev] [--profile default]
#     ruby scripts/jira_project_setup.rb status   [--env dev]
#
# Project key convention: PE{ENV}{TEAM}, e.g. PEDEVTBD, PEWPTQW, PEGHATST
#   ENV:  dev → DEV, wp → WP, gha → GHA   (JIRA_ENV env var, default: dev)
#   TEAM: TBD (The Big Dog), TQW (Quality Whisperers), TST (Support Team)

require 'jira-ruby'
require 'net/http'
require 'json'
require 'optparse'
require 'uri'
require 'yaml'
require 'fileutils'
require_relative '../lib/predictability_engine/config'
require_relative '../lib/predictability_engine/jira_workflow'

module JiraProjectSetup
  TEAMS_CONFIG_PATH = File.expand_path('jira_project_setup/teams.yml', __dir__).freeze
  ENV_CODES = { 'dev' => 'DEV', 'wp' => 'WP', 'gha' => 'GHA' }.freeze

  def self.project_key(env, team_abbrev)
    "PE#{ENV_CODES.fetch(env, env.upcase)}#{team_abbrev}"
  end

  def self.load_teams
    YAML.load_file(TEAMS_CONFIG_PATH)['teams']
  end

  # Thin wrapper around the Jira REST API for admin operations not covered by jira-ruby.
  class ApiClient
    def initialize(site, email, token)
      @site = site.chomp('/')
      @email = email
      @token = token
    end

    def get(path)
      request(Net::HTTP::Get, path)
    end

    def post(path, payload)
      request(Net::HTTP::Post, path, payload)
    end

    private

    def request(klass, path, payload = nil)
      uri = URI("#{@site}#{path}")
      req = klass.new(uri)
      req.basic_auth(@email, @token)
      req['Accept'] = 'application/json'
      if payload
        req['Content-Type'] = 'application/json'
        req.body = payload.to_json
      end
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |h| h.request(req) }
      raise "Jira API #{response.code} on #{path}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      response.body.empty? ? {} : JSON.parse(response.body)
    end
  end

  # Checks that each named PE workflow exists in Jira; creates it via API if missing.
  # Workflows are shared across environments (created once per Jira instance).
  class WorkflowProvisioner
    def initialize(api)
      @api = api
    end

    def ensure_workflow(workflow_name, statuses)
      if (existing = find_workflow(workflow_name))
        puts "  Workflow '#{workflow_name}' already exists"
        return existing['id']
      end

      puts "  Creating workflow '#{workflow_name}'..."
      result = @api.post('/rest/api/3/workflow', build_payload(workflow_name, statuses))
      puts "  Created workflow id=#{result['id']}"
      result['id']
    rescue StandardError => e
      warn "  Warning: could not create workflow '#{workflow_name}': #{e.message}"
      warn '  → Create it manually in Jira Admin > Workflows, then re-run.'
      nil
    end

    private

    def find_workflow(name)
      encoded = URI.encode_www_form_component(name)
      @api.get("/rest/api/3/workflow/search?workflowName=#{encoded}")['values']
          &.find { |w| w['name'] == name }
    rescue StandardError
      nil
    end

    def build_payload(name, statuses)
      transitions = build_transitions(statuses)
      {
        name: name,
        description: "Predictability Engine shared test workflow — #{name}",
        statuses: statuses.map { |s| { name: s['name'], statusCategory: category_key(s['category']) } },
        transitions: transitions
      }
    end

    def build_transitions(statuses)
      [{ name: 'Create', from: [], to: statuses.first['name'], type: 'initial' }] +
        statuses.each_cons(2).map do |from, to|
          { name: "To #{to['name']}", from: [from['name']], to: to['name'], type: 'global' }
        end
    end

    def category_key(category)
      { 'to do' => 'TODO', 'in progress' => 'IN_PROGRESS', 'done' => 'DONE' }.fetch(category, 'TODO')
    end
  end

  # Checks that a project exists; creates it via the Jira REST API if missing.
  # Also generates the local workflow config YAML consumed by DataSources::Jira.
  class ProjectProvisioner
    def initialize(api, jira_client)
      @api = api
      @jira_client = jira_client
    end

    def ensure_project(key, name, team_config)
      if project_exists?(key)
        puts "  Project #{key} already exists"
        return key
      end

      puts "  Creating project #{key} — #{name}..."
      account_id = @api.get('/rest/api/3/myself')['accountId']
      @api.post('/rest/api/3/project', {
                  key: key, name: name,
                  projectTypeKey: 'software',
                  projectTemplateKey: 'com.pyxis.greenhopper.jira:gh-scrum-template',
                  leadAccountId: account_id,
                  description: "Predictability Engine test project — #{team_config['name']}"
                })
      puts "  Created project #{key}"
      key
    end

    def generate_workflow_config(project_key, team_config, profile)
      wf = PredictabilityEngine::JiraWorkflow.new(
        profile: profile,
        project: project_key,
        statuses: team_config['statuses']
      )
      path = File.expand_path("~/.config/jira/#{project_key}.workflow.yml")
      wf.write(path)
      puts "  Workflow config → #{path}"
      path
    end

    private

    def project_exists?(key)
      @jira_client.Project.find(key)
      true
    rescue JIRA::HTTPError
      false
    end
  end

  # Seeds N issues per project with a realistic distribution:
  #   ~60 % completed (arrival → departure)
  #   ~30 % in-progress (arrival only)
  #   ~10 % backlog (not started)
  class DataSeeder
    DISTRIBUTION = [
      { share: 0.6, label: :completed },
      { share: 0.3, label: :in_progress },
      { share: 0.1, label: :backlog }
    ].freeze

    def initialize(jira_client, project_key, team_config, count: 25)
      @client = jira_client
      @project_key = project_key
      @team_config = team_config
      @count = count
      @arrivals   = team_config['statuses'].select { |s| s['role'] == 'arrival'    }.map { |s| s['name'] }
      @departures = team_config['statuses'].select { |s| s['role'] == 'departure'  }.map { |s| s['name'] }
    end

    def seed
      puts "  Seeding #{@count} issues into #{@project_key}..."
      @count.times.with_index(1) do |_, idx|
        type = @team_config['issue_types'].rotate(idx - 1).first
        issue = create_issue("PE Test: #{type} #{idx} [#{Time.now.strftime('%H%M%S')}]", type)
        apply_workflow(issue, bucket_for(idx))
        print '.'
        $stdout.flush
      end
      puts ' done.'
    end

    def cleanup
      puts "  Cleaning up PE Test issues in #{@project_key}..."
      issues = @client.Issue.jql("project = #{@project_key} AND summary ~ \"PE Test:\"",
                                 max_results: 500)
      issues.each(&:delete)
      puts "  Removed #{issues.size} issues."
    end

    def count_issues
      @client.Issue.jql("project = #{@project_key}", max_results: 500).size
    rescue StandardError
      0
    end

    private

    def create_issue(summary, type)
      issue = @client.Issue.build
      issue.save!('fields' => {
                    'project' => { 'key' => @project_key },
                    'summary' => summary,
                    'issuetype' => { 'name' => type }
                  })
      issue
    end

    def apply_workflow(issue, bucket)
      case bucket
      when :completed then transition_through(issue, @arrivals + @departures)
      when :in_progress then transition_through(issue, @arrivals)
      end
    end

    def transition_through(issue, status_names)
      status_names.each { |name| transition_to(issue, name) }
    end

    def transition_to(issue, status_name)
      needle = status_name.downcase
      target = @client.Transition.all(issue: issue)
                      .then do |all|
        all.find { |t| t.name.casecmp?(status_name) } ||
          all.find { |t| t.name.downcase.include?(needle) }
      end
      return warn("\n  Warning: no transition to '#{status_name}' for #{issue.key}") unless target

      issue.transitions.build.save!('transition' => { 'id' => target.id })
    end

    def bucket_for(idx)
      ratio = (idx - 1).to_f / @count
      threshold = 0.0
      DISTRIBUTION.each do |d|
        threshold += d[:share]
        return d[:label] if ratio < threshold
      end
      :backlog
    end
  end

  # Orchestrates WorkflowProvisioner, ProjectProvisioner, and DataSeeder
  # for the configured environment.
  class Runner
    def initialize(options)
      @env     = options[:env] || ENV.fetch('JIRA_ENV', 'dev')
      @count   = options[:count] || 25
      @profile = options[:profile] || ENV.fetch('JIRA_PROFILE', nil)
      @command = options[:command]
      cfg = PredictabilityEngine::Config.jira(@profile)
      @api    = ApiClient.new(cfg[:site], cfg[:email], cfg[:token])
      @client = PredictabilityEngine::Config.jira_client(@profile)
      @teams  = JiraProjectSetup.load_teams
    end

    def run
      case @command
      when 'setup'    then setup
      when 'teardown' then teardown
      when 'status'   then status
      else raise "Unknown command '#{@command}'. Use: setup | teardown | status"
      end
    end

    private

    def setup
      puts "Setting up #{@teams.size} Jira projects for ENV=#{@env} (#{@count} issues each)..."
      wf_provisioner = WorkflowProvisioner.new(@api)
      pr_provisioner = ProjectProvisioner.new(@api, @client)

      @teams.each do |team|
        key  = JiraProjectSetup.project_key(@env, team['abbrev'])
        name = "PE #{@env.upcase} - #{team['name']}"
        puts "\n#{key} — #{team['name']}"
        wf_provisioner.ensure_workflow(team['workflow'], team['statuses'])
        pr_provisioner.ensure_project(key, name, team)
        pr_provisioner.generate_workflow_config(key, team, @profile || 'default')
        seeder = DataSeeder.new(@client, key, team, count: @count)
        seeder.cleanup
        seeder.seed
      end
      puts "\nSetup complete."
    end

    def teardown
      puts "Tearing down test data for ENV=#{@env}..."
      @teams.each do |team|
        key = JiraProjectSetup.project_key(@env, team['abbrev'])
        puts "\n#{key}"
        DataSeeder.new(@client, key, team).cleanup
      end
      puts "\nTeardown complete."
    end

    def status
      puts "Project status for ENV=#{@env}:\n\n"
      printf "%-15<key>s %-40<name>s %<items>s\n", key: 'Key', name: 'Name', items: 'Items'
      puts '-' * 65
      @teams.each do |team|
        key = JiraProjectSetup.project_key(@env, team['abbrev'])
        begin
          project = @client.Project.find(key)
          count   = DataSeeder.new(@client, key, team).count_issues
          printf "%-15<key>s %-40<name>s %<count>d\n", key: key, name: project.name, count: count
        rescue StandardError
          printf "%-15<key>s %-40<name>s %<status>s\n", key: key, name: "(#{team['name']})", status: 'NOT FOUND'
        end
      end
    end
  end
end

# ── CLI entry point ────────────────────────────────────────────────────────────
if __FILE__ == $PROGRAM_NAME
  options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: jira_project_setup.rb <setup|teardown|status> [options]'
    opts.on('--env ENV', "Environment: dev|wp|gha  (default: #{ENV.fetch('JIRA_ENV', 'dev')})") do |v|
      options[:env] = v
    end
    opts.on('--count N', Integer, 'Issues per project (default: 25)') do |v|
      options[:count] = v
    end
    opts.on('--profile P', 'Jira credentials profile') do |v|
      options[:profile] = v
    end
  end.parse!

  options[:command] = ARGV.shift

  begin
    JiraProjectSetup::Runner.new(options).run
  rescue StandardError => e
    warn "Error: #{e.message}"
    warn e.backtrace.join("\n") if ENV['DEBUG']
    exit 1
  end
end
