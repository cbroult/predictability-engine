# frozen_string_literal: true

require 'roo'
require_relative '../../lib/predictability_engine'

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

Given(/^a Jira project is seeded with (\d+) test issues( with cleanup)?$/) do |count, cleanup|
  config = PredictabilityEngine::Config.jira(ENV['JIRA_PROFILE'])
  project_key = config[:project]
  
  # Skip if JIRA_SITE is not set (not a real JIRA test run)
  unless config[:site]
    pending "JIRA_SITE environment variable or site config not set. Set it to run @real_jira tests."
  end
  
  unless project_key
    pending "JIRA_PROJECT environment variable or project config not set. Set it to run @real_jira tests."
  end
  
  # Run the seeder script.
  cleanup_flag = cleanup ? "--cleanup" : ""
  system("ruby scripts/jira_seeder.rb --project #{project_key} --count #{count} #{cleanup_flag}")
  expect($?).to be_success
end

Then(/^the JIRA issue contract should be verified for the seeded project$/) do
  config = PredictabilityEngine::Config.jira(ENV['JIRA_PROFILE'])
  project_key = config[:project]
  
  # Set the contract check flag
  set_environment_variable('JIRA_CONTRACT_CHECK', 'true')
  
  # Run a command that loads the data
  step "I run `predictability-engine summary jira`"
end

Given(/^an extra large CSV file named "([^"]*)" with (\d+) completed and (\d+) in progress items$/) do |filename, completed_count, wip_count|
  require 'csv'
  require 'date'
  current_date = Date.parse('2026-04-11')
  
  content = CSV.generate do |csv|
    csv << %w[id title start_date end_date]
    # Completed items
    (1..completed_count.to_i).each do |i|
      start_date = current_date - rand(200..400)
      end_date = start_date + rand(5..30)
      csv << ["PROJ-#{i}", "Task #{i}", start_date.iso8601, end_date.iso8601]
    end
    # WIP items
    (completed_count.to_i + 1..completed_count.to_i + wip_count.to_i).each do |i|
      start_date = current_date - rand(1..100)
      csv << ["PROJ-#{i}", "In Progress Task #{i}", start_date.iso8601, nil]
    end
  end
  write_file(filename, content)
end
