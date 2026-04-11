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

  Scenario Outline: Generating reports in text-based formats
    When I run `predictability-engine report sample_data.csv <format>`
    Then the exit status should be 0
    And a file named "sample_data_report.<extension>" should exist
    And a file named "sample_data_report.<extension>" should contain "<title>"

    Examples:
      | format     | extension | title                           |
      | markdown   | md        | # Full Predictability Dashboard |
      | confluence | conf      | h1. Full Predictability Dashboard|

  Scenario: Generating a PDF report
    When I run `predictability-engine report sample_data.csv pdf`
    Then the exit status should be 0
    And a file named "sample_data_report.pdf" should exist
    And the file "sample_data_report.pdf" should be a valid PDF
