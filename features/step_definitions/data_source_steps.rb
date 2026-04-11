# frozen_string_literal: true

require 'roo'

Given(/^an excel file named "([^"]*)" with items:$/) do |filename, table|
  # We create a dummy file to satisfy the existence check if needed,
  # but the engine will use the mock data if ENV['MOCK_EXCEL_DATA'] is set.
  write_file(filename, 'dummy')
  set_environment_variable('MOCK_EXCEL_DATA', table.hashes.to_json)
end

Given(/^Jira is mocked for filter "([^"]*)" with items:$/) do |_filter_id, table|
  set_environment_variable('MOCK_JIRA', 'true')
  set_environment_variable('JIRA_MOCK_DATA', table.hashes.to_json)
end
