# frozen_string_literal: true

require 'yaml'

Given(/^the following workflow config at "([^"]*)":$/) do |path, content|
  write_file(path, content)
end

Then(/^the merged workflow file "([^"]*)" should include these statuses:$/) do |path, table|
  raw = YAML.load_file(File.join(expand_path('.'), path))
  expect(raw['statuses']).not_to be_nil
  table.raw.each do |name, expected_role|
    status = raw['statuses'].find { |s| s['name'] == name }
    expect(status).not_to(be_nil, "No status named #{name.inspect}; got #{raw['statuses'].map { |s| s['name'] }}")
    expect(status['role']).to eq(expected_role),
                              "Expected #{name.inspect} role #{expected_role.inspect}, got #{status['role'].inspect}"
  end
end
