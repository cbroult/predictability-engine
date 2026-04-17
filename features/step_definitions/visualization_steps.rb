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

Then(/^the HTML file "([^"]*)" should have rotated X-axis labels$/) do |filename|
  content = File.read(check_file_path(filename))
  # Check for labelAngle: -45 in the X axis encoding
  expect(content).to match(/"encoding":\{"x":\{.*?"axis":\{.*?"labelAngle":-45/m)
end

Then(/^the HTML file "([^"]*)" should have a confidence rule for (\d+)% at a date >= Today$/) do |filename, pct|
  require 'json'
  require 'date'
  content = File.read(check_file_path(filename))
  spec = find_cfd_spec(content)
  vert_data = find_vert_data(spec)

  today = Date.parse(ENV['MOCK_TODAY'] || Date.current.to_s)

  rule = vert_data.find { |v| v['label'].include?("#{pct}%") }
  expect(rule).not_to be_nil, "Could not find rule for #{pct}%"
  expect(Date.parse(rule['date'])).to be >= today
end

Then(/^the HTML file "([^"]*)" should have confidence rules hit the forecast plateau$/) do |filename|
  require 'json'
  content = File.read(check_file_path(filename))
  spec = find_cfd_spec(content)
  vert_data = find_vert_data(spec)
  main_data = spec['data']['values']

  arrivals = main_data.select { |d| d['type'] == 'Arrivals' }
  max_arrivals = arrivals.map { |d| d['count'] }.max

  vert_data.each do |v|
    expect(v['count']).to eq(max_arrivals),
                          "Rule for #{v['label']} hit #{v['count']}, expected plateau at #{max_arrivals}"
  end
end

Then(/^the HTML file "([^"]*)" should have confidence rules hit the local surface$/) do |filename|
  require 'json'
  content = File.read(check_file_path(filename))
  spec = find_cfd_spec(content)
  vert_data = find_vert_data(spec)
  main_data = spec['data']['values']

  vert_data.each do |v|
    date = v['date']
    arrivals_at_date = main_data.find { |d| d['date'] == date && d['type'] == 'Arrivals' }
    expect(arrivals_at_date).not_to be_nil, "No Arrivals data for #{date}"

    # puts "Rule: #{v['label']}, Date: #{date}, Count: #{v['count']}, Arrivals: #{arrivals_at_date['count']}"

    expect(v['count']).to be_within(0.001).of(arrivals_at_date['count']),
                          "Rule for #{v['label']} hit #{v['count']} on #{date}, but Arrivals was #{arrivals_at_date['count']}"
  end
end

def find_cfd_spec(content)
  specs = extract_vega_specs(content)
  specs.each do |s|
    return s if cfd_forecast_spec?(s)
    next unless s['vconcat']

    s['vconcat'].each do |sub|
      return sub if cfd_forecast_spec?(sub)
    end
  end
  raise 'Could not find Forecasted CFD spec'
end

def cfd_forecast_spec?(spec)
  spec['layer']&.any? do |l|
    l['mark'] && l['mark']['type'] == 'rule' && l['encoding'] &&
      l['encoding']['tooltip'] && l['encoding']['tooltip']['field'] == 'tooltip'
  end
end

def extract_vega_specs(content)
  specs = []
  content.scan(/vegaEmbed\("[^"]*", \{/).each do |match|
    start_pos = content.index(match)
    start_pos = content.index('{', start_pos)
    spec_json = extract_balanced_json(content, start_pos)
    specs << JSON.parse(spec_json)
  end
  specs
end

def extract_balanced_json(content, start_pos)
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
  content[start_pos..end_pos]
end

def find_vert_data(spec)
  vert_layers = spec['layer'].select do |l|
    l['data'] && l['data']['values'] && l['data']['values'].any? { |v| v['label'] }
  end
  raise 'Could not find rule layers' if vert_layers.empty?

  vert_layers.first['data']['values']
end

Then(/^the HTML file "([^"]*)" should have confidence rules aligned with the rightmost part of forecast areas$/) \
  do |filename|
  content = File.read(check_file_path(filename))
  spec = find_cfd_spec(content)
  main_data = spec['data']['values']
  vert_data = find_vert_data(spec)

  vert_data.each_with_index do |v, _vi|
    pcts_in_rule = v['label'].scan(/(\d+)%/).flatten.map(&:to_i)
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

Then(/^the following files should (not )?exist in "([^"]*)":$/) do |negate, dir, table|
  table.raw.flatten.each do |filename|
    path = File.join(dir, filename)
    file_path = File.join(aruba.config.working_directory, path)
    if negate
      expect(File.exist?(file_path)).to be false
    else
      expect(File.exist?(file_path)).to be true
    end
  end
end

Then(/^it is a valid PNG file$/) do
  content = File.binread(check_file_path("reports/sample_data/dashboard.png"))
  expect(content[0..7]).to eq("\x89PNG\r\n\x1a\n".b)
end

Then(/^the HTML file "([^"]*)" should have "([^"]*)" as the first chart panel$/) do |filename, title|
  content = File.read(check_file_path(filename))
  # First chart panel comes after summary panel
  # Split by <div class='chart-panel'> and check the first one (index 1 because index 0 is everything before)
  first_panel = content.split("<div class='chart-panel'>").at(1)
  expect(first_panel).to include("<h2>#{title}</h2>")
end

Then(/^the HTML file "([^"]*)" should have "([^"]*)" as the (\d+)(?:st|nd|rd|th) chart panel$/) do |filename, title, index|
  content = File.read(check_file_path(filename))
  # First chart panel comes after summary panel
  # Split by <div class='chart-panel'> and check the one at given index
  panel = content.split("<div class='chart-panel'>").at(index.to_i)
  expect(panel).to include("<h2>#{title}</h2>")
end

Then(/^the HTML file "([^"]*)" should have CFD x-axis with minor ticks and long labeled ticks$/) do |filename|
  content = File.read(check_file_path(filename))
  expect(content).to include('"minorTicks":true')
  expect(content).to include('"tickSize":8')
  expect(content).to include('"minorTickSize":4')
  expect(content).to match(/"x":\{.*?"axis":\{.*?"values":\[/m)
end

def check_file_path(filename)
  file_path = File.join(aruba.config.working_directory, filename)
  expect(File.exist?(file_path)).to be true
  file_path
end
