# frozen_string_literal: true

Then(/^the HTML file "([^"]*)" should be valid and visible in a browser$/) do |filename|
  content = File.read(check_file_path(filename))
  expect(content).to include('<html', 'vega')
  expect(content).to match(/vg-canvas|vega-embed/)
end

Then(/^the output should contain ANSI color codes$/) do
  expect(last_command_started.output).to match(/\e\[\d+m/)
end

Then(/^the output should not contain ANSI color codes$/) do
  expect(last_command_started.output).not_to match(/\e\[\d+m/)
end

Then(/^the file "([^"]*)" should be a valid PDF$/) do |filename|
  content = File.binread(check_file_path(filename))
  expect(content[0..3]).to eq('%PDF')
end

def check_file_path(filename)
  file_path = File.join(aruba.config.working_directory, filename)
  expect(File.exist?(file_path)).to be true
  file_path
end
