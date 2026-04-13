# frozen_string_literal: true

Feature: CFD Forecast Expectations
  As a project manager
  I want to see accurate and readable CFD forecasts
  So that I can plan with confidence

  Scenario: X-axis labels are rotated for readability
    Given a file named "rotation_test.csv" with the following adjusted data:
      | id | title | start_date | end_date |
      | 1  | T1    | 2026-03-01 | 2026-03-05 |
    When I run `predictability-engine viz html_forecasted_cfd rotation_test.csv dashboard.html`
    Then the exit status should be 0
    And the HTML file "dashboard.html" should have rotated X-axis labels

  Scenario: CFD confidence rules are placed at correct dates for a small controlled dataset
    Given Today is "2026-03-07"
    And a file named "forecast_test.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Task 1,2026-03-01,2026-03-02
      PROJ-2,Task 2,2026-03-01,2026-03-03
      PROJ-3,Task 3,2026-03-01,2026-03-04
      PROJ-4,Task 4,2026-03-01,2026-03-05
      PROJ-5,Task 5,2026-03-01,2026-03-06
      PROJ-6,Task 6,2026-03-01,
      PROJ-7,Task 7,2026-03-01,
      """
    When I run `predictability-engine viz html_forecasted_cfd forecast_test.csv dashboard.html`
    Then the exit status should be 0
    And the HTML file "dashboard.html" should have a confidence rule for 85% at a date >= Today
    And the HTML file "dashboard.html" should have confidence rules hit the forecast plateau
