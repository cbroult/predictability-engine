# frozen_string_literal: true

# Provision and seed the three PE test projects across dev/wp/gha environments.
#
# Usage:
#   JIRA_SITE=https://acme.atlassian.net JIRA_EMAIL=you@acme.com JIRA_API_TOKEN=... \
#     scripts/jira-project-setup setup   [--env dev] [--count 25] [--profile default]
#     scripts/jira-project-setup teardown [--env dev] [--profile default]
#     scripts/jira-project-setup status   [--env dev]
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
require_relative '../lib/predictability_engine/jira_auth'
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
    CATEGORY_MAP = { 'to do' => 'TODO', 'in progress' => 'IN_PROGRESS', 'done' => 'DONE' }.freeze

    def initialize(api)
      @api = api
    end

    def ensure_workflow(workflow_name, statuses)
      if (existing = find_workflow(workflow_name))
        puts "  Workflow '#{workflow_name}' already exists"
        return existing['id']
      end

      puts "  Creating workflow '#{workflow_name}'..."
      status_ids = ensure_statuses(statuses)
      result = @api.post('/rest/api/3/workflow', build_payload(workflow_name, statuses, status_ids))
      puts "  Created workflow id=#{result['id']}"
      result['id']
    rescue StandardError => e
      warn "  Warning: could not create workflow '#{workflow_name}': #{e.message}"
      warn '  → Create it manually in Jira Admin > Workflows, then re-run.'
      nil
    end

    private

    def ensure_statuses(statuses)
      existing = fetch_existing_statuses
      to_create = statuses.reject { |s| existing.key?(s['name'].downcase) }
      if to_create.any?
        payload = { statuses: to_create.map do |s|
          { name: s['name'], statusCategory: CATEGORY_MAP.fetch(s['category'], 'TODO') }
        end }
        @api.post('/rest/api/3/statuses', payload).each { |s| existing[s['name'].downcase] = s['id'] }
      end
      statuses.to_h { |s| [s['name'], existing[s['name'].downcase]] }
    end

    def fetch_existing_statuses
      result = @api.get('/rest/api/3/statuses/search?maxResults=200')
      (result['values'] || []).to_h { |s| [s['name'].downcase, s['id']] }
    end

    def find_workflow(name)
      encoded = URI.encode_www_form_component(name)
      @api.get("/rest/api/3/workflow/search?workflowName=#{encoded}")['values']
          &.find { |w| w['name'] == name }
    end

    def build_payload(name, statuses, status_ids)
      {
        name: name,
        description: "Predictability Engine shared test workflow — #{name}",
        statuses: statuses.map { |s| { id: status_ids[s['name']] } },
        transitions: build_transitions(statuses, status_ids)
      }
    end

    def build_transitions(statuses, status_ids)
      [{ name: 'Create', to: status_ids[statuses.first['name']], type: 'initial' }] +
        statuses.each_cons(2).map do |from, to|
          { name: "To #{to['name']}", from: [status_ids[from['name']]], to: status_ids[to['name']], type: 'global' }
        end
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
      account_id = @api.get('/rest/api/3/myself')['accountId']

      if project_exists?(key)
        puts "  Project #{key} already exists"
      else
        puts "  Creating project #{key} — #{name}..."
        @api.post('/rest/api/3/project', {
                    key: key, name: name,
                    projectTypeKey: 'software',
                    projectTemplateKey: 'com.pyxis.greenhopper.jira:gh-scrum-template',
                    leadAccountId: account_id,
                    description: "Predictability Engine test project — #{team_config['name']}"
                  })
        puts "  Created project #{key}"
      end

      grant_admin_role(key, account_id)
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

    def grant_admin_role(project_key, account_id)
      roles = @api.get("/rest/api/3/project/#{project_key}/role")
      admin_url = roles.find { |name, _| name.match?(/admin/i) }&.last
      return warn "  Warning: no Administrator role found for #{project_key}" unless admin_url

      role_id = admin_url.split('/').last
      @api.post("/rest/api/3/project/#{project_key}/role/#{role_id}", { user: [account_id] })
      puts '  Granted Administrator role → delete permission enabled'
    rescue StandardError => e
      warn "  Warning: could not grant admin role for #{project_key}: #{e.message}"
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
        bucket = bucket_for(idx)
        summary = "PE Test: #{type} #{idx} [#{Time.now.strftime('%H%M%S')}]"
        issue = create_issue(summary, type, priority_for(bucket, idx))
        apply_workflow(issue, bucket)
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

    def priority_for(bucket, idx)
      case bucket
      when :completed then idx <= (@count * 0.3).ceil ? 'High' : 'Medium'
      when :in_progress then 'Medium'
      else 'Low'
      end
    end

    def create_issue(summary, type, priority)
      build_issue(summary, type, priority)
    rescue JIRA::HTTPError
      warn "\n  Warning: issue type '#{type}' unavailable in #{@project_key}, falling back to 'Task'"
      build_issue(summary, 'Task', priority)
    end

    def build_issue(summary, type, priority)
      issue = @client.Issue.build
      issue.save!('fields' => {
                    'project' => { 'key' => @project_key },
                    'summary' => summary,
                    'issuetype' => { 'name' => type },
                    'priority' => { 'name' => priority }
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
      @teams   = JiraProjectSetup.load_teams
    end

    USAGE = 'Usage: jira-project-setup <setup|teardown|status> [options]'

    def run
      case @command
      when 'setup'    then setup
      when 'teardown' then teardown
      when 'status'   then status
      else
        label = @command.to_s.empty? ? 'No command specified' : "Unknown command '#{@command}'"
        raise "#{label}. Use: setup | teardown | status\n#{USAGE}"
      end
    end

    private

    def each_team_with_key(&block)
      @teams.each { |team| block.call(JiraProjectSetup.project_key(@env, team['abbrev']), team) }
    end

    def setup
      puts "Setting up #{@teams.size} Jira projects for ENV=#{@env} (#{@count} issues each)..."
      wf_provisioner = WorkflowProvisioner.new(api)
      pr_provisioner = ProjectProvisioner.new(api, client)

      each_team_with_key do |key, team|
        name = "PE #{@env.upcase} - #{team['name']}"
        puts "\n#{key} — #{team['name']}"
        wf_provisioner.ensure_workflow(team['workflow'], team['statuses'])
        pr_provisioner.ensure_project(key, name, team)
        pr_provisioner.generate_workflow_config(key, team, @profile || 'default')
        seeder = DataSeeder.new(client, key, team, count: @count)
        seeder.cleanup
        seeder.seed
      end
      puts "\nSetup complete."
    end

    def teardown
      puts "Tearing down test data for ENV=#{@env}..."
      each_team_with_key do |key, team|
        puts "\n#{key}"
        DataSeeder.new(client, key, team).cleanup
      end
      puts "\nTeardown complete."
    end

    def status
      puts "Project status for ENV=#{@env}:\n\n"
      printf "%-15<key>s %-40<name>s %<items>s\n", key: 'Key', name: 'Name', items: 'Items'
      puts '-' * 65
      each_team_with_key do |key, team|
        project = client.Project.find(key)
        count   = DataSeeder.new(client, key, team).count_issues
        printf "%-15<key>s %-40<name>s %<count>d\n", key: key, name: project.name, count: count
      rescue StandardError
        printf "%-15<key>s %-40<name>s %<status>s\n", key: key, name: "(#{team['name']})", status: 'NOT FOUND'
      end
    end

    def api
      @api ||= begin
        cfg = PredictabilityEngine::Config.jira(@profile)
        ApiClient.new(cfg[:site], cfg[:email], cfg[:token])
      end
    end

    def client
      @client ||= PredictabilityEngine::Config.jira_client(@profile)
    end
  end

  def self.run_cli(argv = ARGV)
    options = {}
    OptionParser.new do |opts|
      opts.banner = 'Usage: jira-project-setup <setup|teardown|status> [options]'
      opts.on('--env ENV', "Environment: dev|wp|gha  (default: #{ENV.fetch('JIRA_ENV', 'dev')})") do |v|
        options[:env] = v
      end
      opts.on('--count N', Integer, 'Issues per project (default: 25)') do |v|
        options[:count] = v
      end
      opts.on('--profile P', 'Jira credentials profile') do |v|
        options[:profile] = v
      end
    end.parse!(argv)

    options[:command] = argv.shift

    Runner.new(options).run
  rescue StandardError => e
    warn "Error: #{e.message}"
    warn e.backtrace.join("\n") if ENV['DEBUG']
    exit 1
  end
end

JiraProjectSetup.run_cli if __FILE__ == $PROGRAM_NAME
