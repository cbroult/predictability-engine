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
      | subcommand | filename    | title                            |
      | markdown   | report.md   | # Full Predictability Dashboard  |
      | md         | report.md   | # Full Predictability Dashboard  |
      | confluence | report.conf | h1. Full Predictability Dashboard |
      | conf       | report.conf | h1. Full Predictability Dashboard |

  Scenario: Generating a landscape dashboard via viz
    When I run `predictability-engine viz landscape sample_data.csv`
    Then the exit status should be 0
    And a file named "reports/sample_data/landscape.html" should exist
    And the HTML file "reports/sample_data/landscape.html" should be valid and visible in a browser

  Scenario: Generating a PDF report via viz
    When I run `predictability-engine viz pdf sample_data.csv`
    Then the output should be visible on failure
    And the exit status should be 0
    And a file named "reports/sample_data/report.pdf" should exist
    And the file "reports/sample_data/report.pdf" should be a valid PDF
