# frozen_string_literal: true

require 'yaml'
require 'fileutils'

# Load script without running CLI entry point
module JiraProjectSetup; end unless defined?(JiraProjectSetup)
load File.expand_path('../../scripts/jira_project_setup.rb', __dir__)

# cd to project root (../.. from Aruba's default tmp/aruba working dir)
# so that `bundle exec ruby scripts/jira_project_setup.rb` resolves correctly
Before('@jira_setup') do
  cd('../..')
end

Before('@jira_live') do
  # Copy real credentials into the Aruba home so CLI subprocesses can read
  # them from ~/.config/jira/jira_credentials.yml without touching the real home.
  # Dir.home is the real home; aruba.environment['HOME'] is the isolated Aruba home.
  real_creds = File.join(Dir.home, '.config', 'jira', 'jira_credentials.yml')
  if File.exist?(real_creds)
    aruba_creds = File.join(aruba.environment.fetch('HOME', expand_path('home')),
                            '.config', 'jira', 'jira_credentials.yml')
    FileUtils.mkdir_p(File.dirname(aruba_creds))
    FileUtils.cp(real_creds, aruba_creds)
  end

  profile = ENV.fetch('JIRA_PROFILE', nil)
  raise 'JIRA_PROFILE environment variable must be set to run @jira_live scenarios' if profile.nil? || profile.empty?

  cfg = PredictabilityEngine::Config.jira(profile)
  set_environment_variable('JIRA_PROFILE', profile)
  set_environment_variable('JIRA_SITE', cfg.fetch(:site))
  set_environment_variable('JIRA_EMAIL', cfg.fetch(:email))
  set_environment_variable('JIRA_API_TOKEN', cfg.fetch(:token))
  aruba.config.exit_timeout = 300
end

Given('the Jira project setup script is available') do
  expect(defined?(JiraProjectSetup)).to be_truthy
end

Then('the project key for env {string} and team {string} is {string}') do |env, team, expected|
  expect(JiraProjectSetup.project_key(env, team)).to eq(expected)
end

Then('the teams config has {int} teams') do |count|
  expect(JiraProjectSetup.load_teams.size).to eq(count)
end

Then('each team has abbrev, name, workflow, issue_types, and statuses') do
  JiraProjectSetup.load_teams.each do |team|
    expect(team.keys).to include('abbrev', 'name', 'workflow', 'issue_types', 'statuses')
  end
end

Then('each team has at least one arrival and one departure status') do
  JiraProjectSetup.load_teams.each do |team|
    arrivals   = team['statuses'].select { |s| s['role'] == 'arrival' }
    departures = team['statuses'].select { |s| s['role'] == 'departure' }
    expect(arrivals).not_to be_empty, "#{team['abbrev']} missing arrival"
    expect(departures).not_to be_empty, "#{team['abbrev']} missing departure"
  end
end

Given('a DataSeeder for project {string} with count {int}') do |project_key, count|
  team = JiraProjectSetup.load_teams.find { |t| project_key.include?(t['abbrev']) }
  @seeder = JiraProjectSetup::DataSeeder.new(nil, project_key, team, count: count)
end

Then('issues {int} through {int} are bucketed as completed') do |from, to|
  (from..to).each { |i| expect(@seeder.send(:bucket_for, i)).to eq(:completed) }
end

Then('issues {int} through {int} are bucketed as in_progress') do |from, to|
  (from..to).each { |i| expect(@seeder.send(:bucket_for, i)).to eq(:in_progress) }
end

Then('issues {int} through {int} are bucketed as backlog') do |from, to|
  (from..to).each { |i| expect(@seeder.send(:bucket_for, i)).to eq(:backlog) }
end

Then('the output should match {regexp}') do |pattern|
  expect(last_command_started.output).to match(pattern)
end

Given('the JIRA_PROFILE environment variable is set') do
  # Validation and Aruba env setup happen in the Before('@jira_live') hook.
  # This step exists solely to document the precondition in the scenario.
end
