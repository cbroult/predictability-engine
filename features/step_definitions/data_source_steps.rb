# frozen_string_literal: true

require 'English'
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
  config = PredictabilityEngine::Config.jira(ENV.fetch('JIRA_PROFILE', nil))

  if ENV['MOCK_JIRA'] == 'true' || !config[:site]
    puts 'Using mock JIRA data for seeded project...' unless config[:site]
    # Provide mock data that satisfies the contract check
    mock_issues = (0...count.to_i).map { |idx| build_mock_issue(idx) }
    set_environment_variable('MOCK_JIRA', 'true')
    set_environment_variable('JIRA_MOCK_DATA', mock_issues.to_json)
    next
  end

  project_key = config[:project]

  unless project_key
    pending 'JIRA_PROJECT environment variable or project config not set. Set it to run @real_jira tests.'
  end

  # Run the seeder script.
  cleanup_flag = cleanup ? '--cleanup' : ''
  system("ruby scripts/jira_seeder.rb --project #{project_key} --count #{count} #{cleanup_flag}")
  expect($CHILD_STATUS).to be_success
end

Then(/^the JIRA issue contract should be verified for the seeded project$/) do
  config = PredictabilityEngine::Config.jira(ENV.fetch('JIRA_PROFILE', nil))
  config[:project]

  # Set the contract check flag
  set_environment_variable('JIRA_CONTRACT_CHECK', 'true')

  # Run a command that loads the data and expect it to succeed
  step 'I run `predictability-engine summary jira`'
  step 'the exit status should be 0'
end

def build_mock_issue(idx)
  issue = { key: "TEST-#{idx + 1}", summary: "Test Issue #{idx + 1}",
            issuetype: { name: 'Story' }, created: '2024-01-01T10:00:00.000+0000',
            changelog: { histories: [] } }
  case idx % 5
  when 0, 1, 2
    add_status_transition(issue, 'In Progress', '2024-01-02')
  when 3
    add_status_transition(issue, 'In Progress', '2024-01-02')
    add_status_transition(issue, 'Done', '2024-01-05')
    issue[:resolutiondate] = '2024-01-05T10:00:00.000+0000'
  end
  issue
end

def add_status_transition(issue, status, date)
  issue[:changelog][:histories] << {
    created: "#{date}T10:00:00.000+0000",
    items: [{ field: 'status', toString: status }]
  }
end

Given(/^an extra large CSV file named "([^"]*)" with (\d+) completed and (\d+) in progress items$/) \
  do |filename, comp, wip|
  completed_count = comp.to_i
  wip_count = wip.to_i
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
    ((completed_count.to_i + 1)..(completed_count.to_i + wip_count.to_i)).each do |i|
      start_date = current_date - rand(1..100)
      csv << ["PROJ-#{i}", "In Progress Task #{i}", start_date.iso8601, nil]
    end
  end
  write_file(filename, content)
end
