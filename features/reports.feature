Feature: Report generation in multiple formats
  In order to share my team's flow metrics in different platforms
  As a manager
  I want to generate reports in Markdown, Confluence markup, and PDF

  Background:
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Implement core,2026-03-01,2026-03-05
      PROJ-2,Fix bug A,2026-03-02,2026-03-04
      """

  Scenario Outline: Generating reports via the viz subcommand
    When I run `predictability-engine viz <subcommand> sample_data.csv`
    Then the exit status should be 0
    And a file named "reports/sample_data/<filename>" should exist
    And a file named "reports/sample_data/<filename>" should contain "<title>"

    Examples:
      | subcommand | filename     | title                            |
      | markdown   | dashboard.md | # Full Predictability Dashboard  |
      | md         | dashboard.md | # Full Predictability Dashboard  |
      | confluence | dashboard.conf | h1. Full Predictability Dashboard |
      | conf       | dashboard.conf | h1. Full Predictability Dashboard |

  Scenario: Creating a landscape dashboard layout
    When I run `predictability-engine viz landscape sample_data.csv`
    Then the exit status should be 0
    And a file named "reports/sample_data/dashboard.html" should be found in the directory
    And the HTML file "reports/sample_data/dashboard.html" should be valid and visible in a browser

  Scenario: Generating a forecasted CFD with no stacking
    Given a file named "forecast_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Implement core,2026-03-01,2026-03-05
      PROJ-2,Fix bug A,2026-03-02,2026-03-04
      PROJ-3,In progress,2026-03-03,
      """
    When I run `predictability-engine viz landscape forecast_data.csv`
    Then the exit status should be 0
    And a file named "reports/forecast_data/dashboard.html" should exist
    And the HTML file "reports/forecast_data/dashboard.html" should have vertical rules for confidence levels
    And the HTML file "reports/forecast_data/dashboard.html" should have CFD areas with no stacking
    And the HTML file "reports/forecast_data/dashboard.html" should have confidence rules aligned with the rightmost part of forecast areas

  Scenario Outline: Generating high-fidelity reports via viz
    When I run `predictability-engine viz <subcommand> sample_data.csv`
    Then the output should be visible on failure
    And the exit status should be 0
    And a file named "reports/sample_data/<filename>" should exist
    And the file "reports/sample_data/<filename>" should be a valid PDF
    And the PDF file "reports/sample_data/<filename>" should have 1 page

    Examples:
      | subcommand   | filename      |
      | pdf          | dashboard.pdf |
      | a3_landscape | dashboard_a3.pdf |
