# frozen_string_literal: true

Then(/^the HTML file "([^"]*)" should be valid and visible in a browser$/) do |filename|
  file_path = File.join(aruba.config.working_directory, filename)
  expect(File.exist?(file_path)).to be true
  content = File.read(file_path)
  expect(content).to include('<html')
  expect(content).to include('vega')
  expect(content).to match(/vg-canvas|vega-embed/)
end
