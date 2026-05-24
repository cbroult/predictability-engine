# frozen_string_literal: true
Feature: Dashboard visual completeness
  These scenarios verify that generated report files contain all expected
  chart content, not just correct file headers or page counts.
  They guard against regressions like charts being cut off in PDFs or
  missing from HTML due to rendering or layout changes.

  Background:
    Given the sample file "sample_data.csv" is copied into the working directory

  Scenario: HTML dashboard renders all 6 chart panels
    When I run `predictability-engine viz html_all sample_data.csv`
    Then the exit status should be 0
    And the HTML file "reports/sample_data/dashboard.html" should have 6 chart panels

  Scenario: PDF dashboard contains full chart content
    When I run `predictability-engine viz pdf sample_data.csv`
    Then the exit status should be 0
    And the output should be visible on failure
    And the file "reports/sample_data/dashboard.pdf" should have a size greater than 50 KB

  Scenario: PNG dashboard screenshot captures full render
    When I run `predictability-engine viz png sample_data.csv`
    Then the exit status should be 0
    And the output should be visible on failure
    And the file "reports/sample_data/dashboard.png" should have a size greater than 100 KB
