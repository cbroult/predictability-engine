# frozen_string_literal: true

require 'yaml'
require 'fileutils'

When('I run {command} interactively with input {string}') do |cmd, input|
  run_command(cmd)
  input.split('\n').each { |line| type(line) }
  close_input
  stop_all_commands
end

def expand_path_template(template)
  home = aruba.environment.fetch('HOME', Dir.home)
  template.gsub('$HOME', home).gsub('$JIRA_PROFILE', ENV.fetch('JIRA_PROFILE', ''))
end

Then('a credentials file should exist at {string}') do |path_template|
  expect(File.exist?(expand_path_template(path_template))).to be true
end

Then('the credentials file should contain profile {string}') do |profile|
  fake_home = aruba.environment.fetch('HOME', Dir.home)
  path = File.join(fake_home, '.config', 'jira', 'jira_credentials.yml')
  content = YAML.load_file(path)
  expect(content.dig('profiles', profile)).not_to be_nil
end

def jira_yaml_for(filename)
  PredictabilityEngine::DataSources::JiraYaml.new(expand_path(filename))
end

Then('the Jira profile for {string} is {string}') do |filename, expected_profile|
  expect(jira_yaml_for(filename).profile).to eq(expected_profile)
end

Then('the Jira query for {string} matches both project and filter {string}') do |filename, key|
  query = jira_yaml_for(filename).query
  expect(query).to include(%(project = "#{key}")).and include(%(filter = "#{key}"))
end

Then('the Jira query for {string} is {string}') do |filename, expected|
  expect(jira_yaml_for(filename).query).to eq(expected)
end

Given('a Jira YAML config {string} exists with the current profile') do |filename|
  profile = ENV.fetch('JIRA_PROFILE')
  write_file(filename, "jira_profile: #{profile}\n")
end

Then('a workflow file should exist at {string}') do |path_template|
  expect(File.exist?(File.expand_path(expand_path_template(path_template)))).to be true
end
