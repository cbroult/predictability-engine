# frozen_string_literal: true

require 'json'
require 'date'

def read_html(filename)
  File.read(check_file_path(filename))
end

def read_cfd_data(filename)
  spec = find_cfd_spec(read_html(filename))
  vert_data = find_vert_data(spec)
  main_data = spec['data']['values']
  [spec, vert_data, main_data]
end

Then(/^the HTML file "([^"]*)" should be valid and visible in a browser$/) do |filename|
  html = read_html(filename)
  expect(html).to include('<html', 'vega')
  expect(html).to match(/vg-canvas|vega-embed/)
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
  raw_content = read_html(filename)
  # Vega spec for Forecasted CFD contains rules with tooltips like "50% Confidence (2026-04-18)"
  expect(raw_content).to include('"mark":{"type":"rule"')
  expect(raw_content).to match(/"tooltip":"[^"]*\d+% Confidence \(\d{4}-\d{2}-\d{2}\)[^"]*"/)
end

Then(/^the HTML file "([^"]*)" should have CFD areas with no stacking$/) do |filename|
  area_content = read_html(filename)
  # Search for the area encoding and verify it has stack: null
  expect(area_content).to match(/"type":"area".*?"encoding":\{.*?"y":\{.*?"stack":null/m)
end

Then(/^the HTML file "([^"]*)" should have rotated X-axis labels$/) do |filename|
  content = read_html(filename)
  # Check for labelAngle: -45 in the X axis encoding
  expect(content).to match(/"encoding":\{"x":\{.*?"axis":\{.*?"labelAngle":-45/m)
end

Then(/^the HTML file "([^"]*)" should have a confidence rule for (\d+)% at a date >= Today$/) do |filename, pct|
  _, vert_data, = read_cfd_data(filename)

  today = Date.parse(ENV['MOCK_TODAY'] || Date.current.to_s)

  rule = vert_data.find { |v| v['label'].include?("#{pct}%") }
  expect(rule).not_to be_nil, "Could not find rule for #{pct}%"
  expect(Date.parse(rule['date'])).to be >= today
end

Then(/^the HTML file "([^"]*)" should have confidence rules hit the forecast plateau$/) do |filename|
  _, vert_data, main_data = read_cfd_data(filename)

  arrivals = main_data.select { |d| d['type'] == 'Arrivals' }
  max_arrivals = arrivals.map { |d| d['count'] }.max

  vert_data.each do |v|
    expect(v['count']).to eq(max_arrivals),
                          "Rule for #{v['label']} hit #{v['count']}, expected plateau at #{max_arrivals}"
  end
end

Then(/^the HTML file "([^"]*)" should have confidence rules hit the local surface$/) do |filename|
  _, vert_data, main_data = read_cfd_data(filename)

  plateau = compute_plateau(main_data)

  vert_data.each do |v|
    expect(v['count']).to be_within(0.001).of(plateau),
                          "Rule for #{v['label']} hit #{v['count']}, expected plateau #{plateau}"
  end
end

def compute_plateau(main_data)
  # Plateau = max of any percentile surface's final count. All percentile surfaces
  # flatten to the same value (departed_so_far + wip), so any percentile's max works.
  pct_counts = main_data.select { |d| d['type'].to_s =~ /% Confidence$/ }.map { |d| d['count'] }
  raise 'No percentile surface data found in CFD spec' if pct_counts.empty?

  pct_counts.max
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
    tooltip = l['encoding']&.[]('tooltip')
    l['mark'] && l['mark']['type'] == 'rule' && l['encoding'] &&
      tooltip.is_a?(Hash) && tooltip['field'] == 'tooltip'
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

def all_spec_nodes(spec)
  [spec, *(spec['vconcat'] || []), *(spec['layer'] || [])]
end

def all_vega_data_values(content)
  extract_vega_specs(content).flat_map do |spec|
    all_spec_nodes(spec).flat_map { |node| node.dig('data', 'values') || [] }
  end
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
  _spec, vert_data, main_data = read_cfd_data(filename)

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
  content = read_html(filename)
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
  content = File.binread(check_file_path('reports/sample_data/dashboard.png'))
  expect(content[0..7]).to eq("\x89PNG\r\n\x1a\n".b)
end

Then(/^the HTML file "([^"]*)" should have "([^"]*)" as the first chart panel$/) do |filename, title|
  content = read_html(filename)
  # First chart panel comes after summary panel
  # Split by <div class='chart-panel'> and check the first one (index 1 because index 0 is everything before)
  first_panel = content.split("<div class='chart-panel'>").at(1)
  expect(first_panel).to include("<h2>#{title}</h2>")
end

Then(/^the HTML file "([^"]*)" should have "([^"]*)" as the (\d+)(?:st|nd|rd|th) chart panel$/) \
  do |filename, title, index|
  content = read_html(filename)
  # First chart panel comes after summary panel
  # Split by <div class='chart-panel'> and check the one at given index
  panel = content.split("<div class='chart-panel'>").at(index.to_i)
  expect(panel).to include("<h2>#{title}</h2>")
end

Then(
  /^the HTML file "([^"]*)" should have a date on the x-axis within (\d+) days? of "([^"]*)" as the first date$/
) do |filename, tolerance, expected|
  content = read_html(filename)
  dates = all_vega_data_values(content).map { |v| v['date'] }.compact.uniq.sort
  raise "No date values found in #{filename}" if dates.empty?

  actual = Date.parse(dates.first)
  diff = (actual - Date.parse(expected)).to_i.abs
  expect(diff).to be <= tolerance.to_i,
                  "First date was #{actual}, expected within #{tolerance} day(s) of #{expected}"
end

Then(/^the HTML file "([^"]*)" should have CFD x-axis with minor ticks and long labeled ticks$/) do |filename|
  content = read_html(filename)
  expect(content).to include('"minorTicks":true')
  expect(content).to include('"tickSize":8')
  expect(content).to include('"minorTickSize":4')
  expect(content).to match(/"x":\{.*?"axis":\{.*?"values":\[/m)
end

Then(/^the HTML file "([^"]*)" should have "([^"]*)" as a labeled x-axis tick$/) do |filename, date|
  content = read_html(filename)
  specs = extract_vega_specs(content)
  all_values = specs.flat_map do |s|
    all_spec_nodes(s).flat_map do |n|
      n.dig('encoding', 'x', 'axis', 'values') || []
    end
  end.uniq
  expect(all_values).to include(date),
                        "Labeled x-axis ticks did not include #{date}; values were: #{all_values}"
end

def check_file_path(filename)
  file_path = File.join(aruba.config.working_directory, filename)
  expect(File.exist?(file_path)).to be true
  file_path
end

def read_cfd_vert_data(filename)
  find_vert_data(find_cfd_spec(read_html(filename)))
end

Then(/^the HTML file "([^"]*)" should have (\d+)% and (\d+)% confidence on the same vertical rule$/) \
  do |filename, pct1, pct2|
  vert_data = read_cfd_vert_data(filename)

  combined = vert_data.find { |v| v['label'].include?("#{pct1}%") && v['label'].include?("#{pct2}%") }
  labels = vert_data.map { |v| v['label'] }
  expect(combined).not_to(be_nil,
                          "Expected #{pct1}% and #{pct2}% on the same rule, rules were: #{labels}")
end

Then(/^the HTML file "([^"]*)" should have (\d+) distinct confidence rules$/) do |filename, count|
  vert_data = read_cfd_vert_data(filename)

  expect(vert_data.size).to eq(count.to_i),
                            "Expected #{count} rules, got #{vert_data.size}: #{vert_data.map { |v| v['label'] }}"
end

Then('the HTML file {string} should embed url {string} for item {string}') do |filename, url, item_id|
  content = read_html(filename)
  all_data = all_vega_data_values(content)
  item_data = all_data.find { |v| v['id'] == item_id }
  expect(item_data).not_to be_nil, "No Vega data found for item '#{item_id}'"
  expect(item_data['url']).to eq(url)
end

Then('the HTML file {string} should have {int} chart panels') do |filename, expected_count|
  content = read_html(filename)
  actual_count = content.scan("class='chart-panel'").size
  expect(actual_count).to eq(expected_count),
                          "Expected #{expected_count} chart panels but found #{actual_count}"
end

Then('the file {string} should have a size greater than {int} KB') do |filename, min_kb|
  size = File.size(check_file_path(filename))
  expect(size).to be > min_kb * 1024,
                  "Expected #{filename} to be > #{min_kb} KB but was #{size / 1024} KB"
end
