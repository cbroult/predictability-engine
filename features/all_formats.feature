Feature: All formats report generation
  In order to have multiple versions of my report at once
  As a manager
  I want to run a single command to generate all formats

  Background:
    Given the template CSV file "sample_data.csv" is adjusted to recent dates and saved as "sample_data.csv"

  Scenario: Generating all formats at once
    When I run `predictability-engine viz all_formats sample_data.csv`
    Then the exit status should be 0
    And the output should contain "Aging Work In Progress"
    And the output should contain "Forecasted Cumulative Flow Diagram"
    And the output should not contain "Report generated at reports/sample_data/dashboard.terminal"
    And the following files should exist in "reports/sample_data":
      | dashboard.html  |
      | dashboard.pdf   |
      | dashboard.png   |
      | dashboard.md    |
      | dashboard.conf  |
      | dashboard.pptx  |

  Scenario: Cleaning up old reports to prevent cruft
    Given a file named "reports/sample_data/old_cruft.txt" with "old content"
    When I run `predictability-engine viz all_formats sample_data.csv`
    Then the following files should not exist in "reports/sample_data":
      | old_cruft.txt |
