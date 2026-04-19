# frozen_string_literal: true

require 'yaml'
require 'predictability_engine'

Given(/^the following workflow config at "([^"]*)":$/) do |path, content|
  write_file(path, content)
end

REFRESH_STEP = /^I refresh the workflow at "([^"]*)" with fresh statuses from "([^"]*)" writing to "([^"]*)"$/
When(REFRESH_STEP) do |existing, fresh, output|
  base = expand_path('.')
  existing_wf = PredictabilityEngine::JiraWorkflow.load(File.join(base, existing))
  fresh_wf    = PredictabilityEngine::JiraWorkflow.load(File.join(base, fresh))
  existing_wf.refresh(fresh_wf).write(File.join(base, output))
end

When(/^I load the workflow from "([^"]*)"$/) do |path|
  @loaded_workflow = PredictabilityEngine::JiraWorkflow.load(File.join(expand_path('.'), path))
end

Then(/^the merged workflow file "([^"]*)" should include these statuses:$/) do |path, table|
  raw = YAML.load_file(File.join(expand_path('.'), path))
  expect(raw['statuses']).not_to be_nil
  table.raw.each do |name, expected_role|
    status = raw['statuses'].find { |s| s['name'] == name }
    expect(status).not_to(be_nil, "No status named #{name.inspect}; got #{raw['statuses'].map { |s| s['name'] }}")
    actual = status['role'].to_s
    expect(actual).to eq(expected_role),
                      "Expected #{name.inspect} role #{expected_role.inspect}, got #{actual.inspect}"
  end
end

Then(/^the workflow file "([^"]*)" should not include a status named "([^"]*)"$/) do |path, name|
  raw = YAML.load_file(File.join(expand_path('.'), path))
  names = (raw['statuses'] || []).map { |s| s['name'] }
  expect(names).not_to include(name)
end

Then(/^the workflow file "([^"]*)" should have arrival names:$/) do |path, table|
  wf = PredictabilityEngine::JiraWorkflow.load(File.join(expand_path('.'), path))
  expect(wf.arrival_names).to match_array(table.raw.flatten)
end

Then(/^the workflow file "([^"]*)" should have departure names:$/) do |path, table|
  wf = PredictabilityEngine::JiraWorkflow.load(File.join(expand_path('.'), path))
  expect(wf.departure_names).to match_array(table.raw.flatten)
end

Then(/^the workflow arrival names should be "([^"]*)" and "([^"]*)"$/) do |name1, name2|
  expect(@loaded_workflow.arrival_names).to match_array([name1, name2])
end

Then(/^the workflow departure names should be "([^"]*)" and "([^"]*)"$/) do |name1, name2|
  expect(@loaded_workflow.departure_names).to match_array([name1, name2])
end
