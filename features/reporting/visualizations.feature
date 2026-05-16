Feature: Visualization command
  In order to visually understand my team's flow metrics
  As a manager
  I want to see graphical representations in my terminal

  Background:
    Given the template CSV file "sample_data.csv" is adjusted to recent dates and saved as "sample_data.csv"

  Scenario Outline: Terminal visualizations
    When I run `predictability-engine viz <command> sample_data.csv`
    Then the exit status should be 0
    And the output should contain "<title>"

    Examples:
      | command    | title                    |
      | scatter    | Cycle Time Scatter Plot  |
      | throughput | Throughput Histogram     |
      | cfd        | Cumulative Flow Diagram  |

  Scenario: Running viz all on sample data
    When I run `predictability-engine viz all sample_data.csv`
    Then the exit status should be 0
    And the output should contain "Flow Metrics Summary"
    And the output should contain "Cycle Time Scatter Plot"
    And the output should contain "Throughput Histogram"
    And the output should contain "Cumulative Flow Diagram"

  Scenario: Validating HTML output in a browser and naming convention
    When I run `predictability-engine viz html_all sample_data.csv`
    Then the exit status should be 0
    And the output should contain "Report generated at reports/sample_data/dashboard.html"
    And a file named "reports/sample_data/dashboard.html" should exist
    And the HTML file "reports/sample_data/dashboard.html" should be valid and visible in a browser
    And a file named "reports/sample_data/dashboard.html" should contain "Flow Metrics Summary"

  Scenario: Visualizing forecasted CFD in terminal
    Given a file named "forecast_input.csv" with the following adjusted data:
      | id     | title  | start_date | end_date   |
      | PROJ-1 | Done 1 | 2026-03-01 | 2026-03-05 |
      | PROJ-2 | WIP 1  | 2026-03-05 |            |
      | PROJ-3 | WIP 2  | 2026-03-06 |            |
    When I run `predictability-engine viz forecasted_cfd forecast_input.csv`
    Then the exit status should be 0
    And the output should contain "Forecasted Cumulative Flow Diagram"

  Scenario: Visualizing forecasted CFD in HTML
    Given a file named "html_forecast_input.csv" with the following adjusted data:
      | id     | title       | start_date | end_date   |
      | H-1    | HTML Item   | 2026-03-01 | 2026-03-05 |
      | H-2    | HTML Active | 2026-03-05 |            |
    When I run `predictability-engine viz html_forecasted_cfd html_forecast_input.csv`
    Then the exit status should be 0
    And a file named "reports/html_forecast_input/forecasted_cfd.html" should exist
    And the HTML file "reports/html_forecast_input/forecasted_cfd.html" should be valid and visible in a browser

  Scenario Outline: Color support in various commands
    When I run `predictability-engine <command> <flag>`
    Then the exit status should be 0
    And the output <condition> contain ANSI color codes

    Examples:
      | command                                 | flag       | condition |
      | viz all sample_data.csv                 | --color    | should    |
      | viz all sample_data.csv                 | --no-color | should not|
      | report sample_data.csv terminal         | --color    | should    |
      | report sample_data.csv terminal         | --no-color | should not|
      | summary sample_data.csv                 | --color    | should    |
      | summary sample_data.csv                 | --no-color | should not|

  Scenario: Dynamic verification of HTML report updates
    Given a file named "dynamic_test.csv" with the following adjusted data:
      | id     | title          | start_date | end_date   |
      | DYN-1  | Primary Item   | 2026-03-01 | 2026-03-02 |
    When I run `predictability-engine viz html_all dynamic_test.csv`
    Then the exit status should be 0
    And a file named "reports/dynamic_test/dashboard.html" should contain "Total Items:</strong> <span class='metric-value'>1</span>"
    Given a file named "dynamic_test.csv" with the following adjusted data:
      | id     | title          | start_date | end_date   |
      | DYN-A  | Alpha Item     | 2026-03-01 | 2026-03-02 |
      | DYN-B  | Beta Item      | 2026-03-01 | 2026-03-02 |
    When I run `predictability-engine viz html_all dynamic_test.csv`
    Then the exit status should be 0
    And a file named "reports/dynamic_test/dashboard.html" should contain "Total Items:</strong> <span class='metric-value'>2</span>"

  Scenario: Verifying Forecasted CFD vertical lines in HTML report
    Given a file named "align_test.csv" with the following adjusted data:
      | id     | title | start_date | end_date   |
      | PROJ-1 | Done  | 2026-04-01 | 2026-04-02 |
      | PROJ-2 | WIP   | 2026-04-05 |            |
    When I run `predictability-engine viz html_forecasted_cfd align_test.csv`
    Then the exit status should be 0
    And the HTML file "reports/align_test/forecasted_cfd.html" should have vertical rules for confidence levels

  Scenario: Verifying Aging WIP position and CFD axis labeling in dashboard
    Given the template CSV file "sample_data.csv" is adjusted to recent dates and saved as "sample_data.csv"
    When I run `predictability-engine viz html_all sample_data.csv`
    Then the exit status should be 0
    And a file named "reports/sample_data/dashboard.html" should exist
    And the HTML file "reports/sample_data/dashboard.html" should have "Aging Work In Progress" as the first chart panel
    And the HTML file "reports/sample_data/dashboard.html" should have "Cumulative Flow Diagram" as the 3rd chart panel
    And the HTML file "reports/sample_data/dashboard.html" should have CFD x-axis with minor ticks and long labeled ticks

  Scenario: Verifying CFD axis labeling for a long-term project
    Given a file named "long_term.csv" with the following adjusted data:
      | id | title | start_date | end_date |
      | L1 | Item 1 | 2026-01-01 | 2026-01-02 |
      | L2 | Item 2 | 2026-06-01 | 2026-06-02 |
    When I run `predictability-engine viz html_cfd long_term.csv`
    Then the exit status should be 0
    And a file named "reports/long_term/cfd.html" should exist
    And the HTML file "reports/long_term/cfd.html" should have CFD x-axis with minor ticks and long labeled ticks
