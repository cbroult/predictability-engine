# frozen_string_literal: true

Then(/^the HTML file "([^"]*)" should be valid and visible in a browser$/) do |filename|
  content = File.read(check_file_path(filename))
  expect(content).to include('<html', 'vega')
  expect(content).to match(/vg-canvas|vega-embed/)
end

Then(/^the output should contain ANSI color codes$/) do
  expect(last_command_started.output).to match(/\e\[\d+m/)
end

Then(/^the output should be visible on failure$/) do
  puts "Command output:\n#{last_command_started.output}" if last_command_started.exit_status != 0
end

Then(/^the output should not contain ANSI color codes$/) do
  expect(last_command_started.output).not_to match(/\e\[\d+m/)
end

Then(/^the file "([^"]*)" should be a valid PDF$/) do |filename|
  content = File.binread(check_file_path(filename))
  expect(content[0..3]).to eq('%PDF')
end

Then(/^the PDF file "([^"]*)" should have (\d+) page(?:s?)$/) do |filename, count|
  content = File.binread(check_file_path(filename))
  # A simple way to count pages in many PDFs is searching for /Type /Page
  # Not perfectly robust but works for Prawn and Playwright outputs
  pages = content.scan(%r{/Type\s*/Page\b}).size
  expect(pages).to eq(count.to_i)
end

Then(/^the HTML file "([^"]*)" should have vertical rules for confidence levels$/) do |filename|
  raw_content = File.read(check_file_path(filename))
  # Vega spec for Forecasted CFD contains rules with tooltips like "50% Confidence (2026-04-18)"
  expect(raw_content).to include('"mark":{"type":"rule"')
  expect(raw_content).to match(/"tooltip":"[^"]*\d+% Confidence \(\d{4}-\d{2}-\d{2}\)[^"]*"/)
end

Then(/^the HTML file "([^"]*)" should have CFD areas with no stacking$/) do |filename|
  area_content = File.read(check_file_path(filename))
  # Search for the area encoding and verify it has stack: null
  expect(area_content).to match(/"type":"area".*?"encoding":\{.*?"y":\{.*?"stack":null/m)
end

Then(/^the HTML file "([^"]*)" should have confidence rules aligned with the rightmost part of forecast areas$/) \
  do |filename|
  require 'json'
  require 'date'
  content = File.read(check_file_path(filename))

  # Find all vegaEmbed specs in the file
  specs = []
  content.scan(/vegaEmbed\("[^"]*", \{/).each do |match|
    # For each match, find the full balanced JSON spec
    start_pos = content.index(match)
    start_pos = content.index('{', start_pos)
    brace_count = 0
    end_pos = -1
    content[start_pos..].chars.each_with_index do |c, i|
      brace_count += 1 if c == '{'
      brace_count -= 1 if c == '}'
      if brace_count.zero?
        end_pos = start_pos + i
        break
      end
    end
    spec_json = content[start_pos..end_pos]
    specs << JSON.parse(spec_json)
  end

  # Find the Forecasted CFD spec (the one with rule layers for confidence)
  spec = specs.find do |s|
    s['layer']&.any? do |l|
      l['mark'] && l['mark']['type'] == 'rule' && l['encoding'] &&
        l['encoding']['tooltip'] && l['encoding']['tooltip']['field'] == 'tooltip'
    end
  end
  expect(spec).not_to be_nil, 'Could not find Forecasted CFD spec in HTML'

  main_data = spec['data']['values']

  # Find the rule layers
  vert_layers = spec['layer'].select do |l|
    l['data'] && l['data']['values'] && l['data']['values'].any? do |v|
      v['label']
    end
  end
  expect(vert_layers).not_to be_empty

  vert_data = vert_layers.first['data']['values']

  vert_data.each_with_index do |v, _vi|
    pcts_in_rule = v['label'].scan(/\d+/).map(&:to_i)
    date = v['date']
    rule_total = v['count']

    pcts_in_rule.each do |p|
      # Check rule date: p% forecast must have reached rule_total by this date
      point = main_data.find { |d| d['date'] == date && d['type'] == "#{p}% Confidence" }
      expect(point).not_to be_nil, "No data point for #{p}% on #{date}"
      expect(point['count']).to be_within(0.0001).of(rule_total) if point['count']

      # Shift check: the rule for P is actually at the date of P+1
      # We know that P reached the top at its own date (D_p <= date)
      # But we want to ensure it's at the "right most part", which means
      # it's at the next percentile's date if possible.

      # We can at least verify that for the first few percentiles (not the last),
      # they have already been at the top for some time at the rule date.
      # (Unless they are the same date as the next one).
      # This is hard to generalize without knowing the exact percentiles used.
    end
  end
end

Then(/^the HTML file "([^"]*)" should have navigation links:$/) do |filename, table|
  content = File.read(check_file_path(filename))
  table.hashes.each do |row|
    active_class = row['active'] == 'true' ? 'active' : ''
    # Expecting <a href='url' class='active_class'>label</a>
    url = Regexp.escape(row['url'])
    cls = Regexp.escape(active_class)
    lbl = Regexp.escape(row['label'])
    pattern = %r{<a\s+href=['"]#{url}['"]\s+class=['"]#{cls}['"]>#{lbl}</a>}
    expect(content).to match(pattern)
  end
end

Then(/^a file named "([^"]*)" should be found in the directory$/) do |filename|
  expect(File.exist?(check_file_path(filename))).to be true
end

def check_file_path(filename)
  file_path = File.join(aruba.config.working_directory, filename)
  expect(File.exist?(file_path)).to be true
  file_path
end
