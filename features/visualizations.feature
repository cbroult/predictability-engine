Feature: Visualization command
  In order to visually understand my team's flow metrics
  As a manager
  I want to see graphical representations in my terminal

  Background:
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Implement core,2026-03-01,2026-03-05
      PROJ-2,Fix bug A,2026-03-02,2026-03-04
      """

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

  Scenario: Running viz forecasted_cfd on sample data
    Given a file named "wip_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Done 1,2026-03-01,2026-03-05
      PROJ-2,Done 2,2026-03-02,2026-03-04
      PROJ-3,WIP 1,2026-03-05,
      PROJ-4,WIP 2,2026-03-06,
      """
    When I run `predictability-engine viz forecasted_cfd wip_data.csv`
    Then the exit status should be 0
    And the output should contain "Forecasted Cumulative Flow Diagram"
    And the output should contain "50% Confidence"

  Scenario: Running viz html_forecasted_cfd on sample data
    Given a file named "wip_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Done 1,2026-03-01,2026-03-05
      PROJ-2,WIP 1,2026-03-05,
      """
    When I run `predictability-engine viz html_forecasted_cfd wip_data.csv`
    Then the exit status should be 0
    And a file named "reports/wip_data/forecasted_cfd.html" should exist
    And the HTML file "reports/wip_data/forecasted_cfd.html" should be valid and visible in a browser

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
    Given a file named "dynamic_test.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2026-03-01,2026-03-02
      """
    When I run `predictability-engine viz html_all dynamic_test.csv`
    Then the exit status should be 0
    And a file named "reports/dynamic_test/dashboard.html" should contain "Total Items:</strong> 1"
    Given a file named "dynamic_test.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2026-03-01,2026-03-02
      PROJ-2,Item 2,2026-03-01,2026-03-02
      """
    When I run `predictability-engine viz html_all dynamic_test.csv`
    Then the exit status should be 0
    And a file named "reports/dynamic_test/dashboard.html" should contain "Total Items:</strong> 2"
