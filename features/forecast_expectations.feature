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

  Scenario: Percentiles that forecast to the same day share a single vertical rule
    # With a steady 1-item-per-day throughput, every percentile for a backlog of 3
    # collapses to the same forecast day. The rule must carry a combined label
    # (e.g. "50%, 75%, 85%, 95%, 98% (date)") rather than rendering as five rules.
    Given Today is "2026-04-20"
    And a file named "steady.csv" with:
      """
      id,title,start_date,end_date
      D1,D1,2026-04-01,2026-04-02
      D2,D2,2026-04-02,2026-04-03
      D3,D3,2026-04-03,2026-04-04
      D4,D4,2026-04-04,2026-04-05
      D5,D5,2026-04-05,2026-04-06
      D6,D6,2026-04-06,2026-04-07
      D7,D7,2026-04-07,2026-04-08
      D8,D8,2026-04-08,2026-04-09
      D9,D9,2026-04-09,2026-04-10
      D10,D10,2026-04-10,2026-04-11
      W1,W1,2026-04-19,
      W2,W2,2026-04-19,
      W3,W3,2026-04-19,
      """
    When I successfully run `predictability-engine viz html_forecasted_cfd steady.csv`
    Then the HTML file "reports/steady/forecasted_cfd.html" should have 1 distinct confidence rules
    And the HTML file "reports/steady/forecasted_cfd.html" should have 95% and 98% confidence on the same vertical rule
    And the HTML file "reports/steady/forecasted_cfd.html" should have confidence rules hit the local surface

  Scenario: sample_data_large — every confidence rule hits the percentile plateau
    # Locks in the Y-axis invariant against the real large sample dataset.
    Given Today is "2026-04-18"
    And the sample file "sample_data_large.csv" is copied into the working directory
    When I successfully run `predictability-engine viz html_forecasted_cfd sample_data_large.csv`
    Then a file named "reports/sample_data_large/forecasted_cfd.html" should exist
    And the HTML file "reports/sample_data_large/forecasted_cfd.html" should have confidence rules hit the local surface

  Scenario: sample_data_large — CFD confidence rules reflect backlog-depletion, not cycle-time
    # CAUTION: the Forecasted CFD's vertical confidence rules are Monte Carlo
    # backlog-depletion percentiles ("when will all current WIP be done?"),
    # NOT cycle-time percentiles ("what single-item completion time does X% of items achieve?").
    # Even when CT p95 == CT p98 (both 21 days for this dataset), the backlog forecast
    # still produces distinct dates because it answers a different question.
    Given Today is "2026-04-18"
    And the sample file "sample_data_large.csv" is copied into the working directory
    When I successfully run `predictability-engine viz html_forecasted_cfd sample_data_large.csv`
    Then the HTML file "reports/sample_data_large/forecasted_cfd.html" should have 5 distinct confidence rules
