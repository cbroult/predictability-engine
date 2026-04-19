# frozen_string_literal: true

require 'yaml'

# Load script without running CLI entry point
module JiraProjectSetup; end unless defined?(JiraProjectSetup)
load File.expand_path('../../scripts/jira_project_setup.rb', __dir__)

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

Then('issue {int} is bucketed as backlog') do |idx|
  expect(@seeder.send(:bucket_for, idx)).to eq(:backlog)
end
