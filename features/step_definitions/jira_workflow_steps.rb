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

Then(/^the workflow file "([^"]*)" should contain exactly:$/) do |path, expected_content|
  actual   = YAML.load_file(File.join(expand_path('.'), path))
  expected = YAML.safe_load(expected_content)
  expect(actual).to eq(expected)
end

Then(/^the workflow arrival names should be "([^"]*)" and "([^"]*)"$/) do |name1, name2|
  expect(@loaded_workflow.arrival_names).to match_array([name1, name2])
end

Then(/^the workflow departure names should be "([^"]*)" and "([^"]*)"$/) do |name1, name2|
  expect(@loaded_workflow.departure_names).to match_array([name1, name2])
end
