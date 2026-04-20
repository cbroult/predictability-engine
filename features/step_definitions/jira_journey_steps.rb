# frozen_string_literal: true

require 'yaml'
require 'fileutils'

When('I run {command} interactively with input {string}') do |cmd, input|
  run_command(cmd)
  input.split('\n').each { |line| type(line) }
  close_input
  stop_all_commands
end

Then('a credentials file should exist at {string}') do |path_template|
  expanded = path_template.gsub('$HOME', Dir.home)
  expect(File.exist?(expanded)).to be true
end

Then('the credentials file should contain profile {string}') do |profile|
  fake_home = aruba.environment.fetch('HOME', Dir.home)
  path = File.join(fake_home, '.config', 'jira', 'jira_credentials.yml')
  content = YAML.load_file(path)
  expect(content.dig('profiles', profile)).not_to be_nil
end

Then('the Jira profile for {string} is {string}') do |filename, expected_profile|
  path = expand_path(filename)
  expect(PredictabilityEngine::DataSources::JiraYaml.new(path).profile).to eq(expected_profile)
end

Then('the Jira query for {string} matches both project and filter {string}') do |filename, key|
  path = expand_path(filename)
  query = PredictabilityEngine::DataSources::JiraYaml.new(path).query
  expect(query).to include(%(project = "#{key}")).and include(%(filter = "#{key}"))
end

Then('the Jira query for {string} is {string}') do |filename, expected|
  path = expand_path(filename)
  expect(PredictabilityEngine::DataSources::JiraYaml.new(path).query).to eq(expected)
end

Given('a Jira YAML config {string} exists with the current profile') do |filename|
  profile = ENV.fetch('JIRA_PROFILE')
  write_file(filename, "jira_profile: #{profile}\n")
end

Then('a workflow file should exist at {string}') do |path_template|
  expanded = path_template
             .gsub('$HOME', Dir.home)
             .gsub('$JIRA_PROFILE', ENV.fetch('JIRA_PROFILE', ''))
  expect(File.exist?(File.expand_path(expanded))).to be true
end
