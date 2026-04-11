Feature: All formats report generation
  In order to have multiple versions of my report at once
  As a manager
  I want to run a single command to generate all formats

  Background:
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Implement core,2026-03-01,2026-03-05
      PROJ-2,Fix bug A,2026-03-02,2026-03-04
      """

  Scenario: Generating all formats at once
    When I run `predictability-engine viz all_formats sample_data.csv`
    Then the exit status should be 0
    And the output should contain "Aging Work In Progress"
    And the output should contain "Forecasted Cumulative Flow Diagram"
    And the output should not contain "Report generated at reports/sample_data/dashboard.terminal"
    And a file named "reports/sample_data/dashboard.html" should exist
    And a file named "reports/sample_data/dashboard.pdf" should exist
    And a file named "reports/sample_data/dashboard.md" should exist
    And a file named "reports/sample_data/dashboard.conf" should exist
    And a file named "reports/sample_data/dashboard_a3.pdf" should exist
    And a file named "reports/sample_data/dashboard.pptx" should exist
    And the following files should not exist:
      | reports/sample_data/dashboard.terminal |
      | reports/sample_data/dashboard_a3_landscape.pdf |
