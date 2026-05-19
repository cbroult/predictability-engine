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

def credentials_file_content
  home = aruba.environment.fetch('HOME', Dir.home)
  YAML.load_file(File.join(home, '.config', 'jira', 'jira_credentials.yml'))
end

Then('a credentials file should exist at {string}') do |path_template|
  expect(File.exist?(expand_path_template(path_template))).to be true
end

Then('the credentials file should contain profile {string}') do |profile|
  expect(credentials_file_content.dig('profiles', profile)).not_to be_nil
end

Then('the credentials file should contain profile {string} with context_path {string}') do |profile, expected|
  expect(credentials_file_content.dig('profiles', profile, 'context_path')).to eq(expected)
end

Then('the credentials file should contain profile {string} with auth_mode {string}') do |profile, expected|
  expect(credentials_file_content.dig('profiles', profile, 'auth_mode')).to eq(expected)
end

Then('the credentials file should contain profile {string} with bearer_token {string}') do |profile, expected|
  expect(credentials_file_content.dig('profiles', profile, 'bearer_token')).to eq(expected)
end

Then('the credentials file should contain profile {string} with auth_cookie {string}') do |profile, expected|
  expect(credentials_file_content.dig('profiles', profile, 'auth_cookie')).to eq(expected)
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

When('I run the jira_workflow command for the current profile') do
  profile = aruba.environment.fetch('JIRA_PROFILE', ENV.fetch('JIRA_PROFILE', ''))
  run_command_and_stop("predictability-engine jira_workflow #{profile}", fail_on_error: true)
end
