Feature: CFD range configuration
  In order to focus on relevant periods of project flow
  As a manager
  I want to configure the history range shown in the CFDs

  Background:
    Given Today is "2026-04-17"
    And a file named "cfd_range_data.csv" with the following adjusted data:
      | id | title    | start_date | end_date   |
      | 1  | Very Old | 2026-02-01 | 2026-02-05 |
      | 2  | Old      | 2026-03-01 | 2026-03-05 |
      | 3  | Med      | 2026-03-15 | 2026-03-20 |
      | 4  | New      | 2026-04-01 | 2026-04-10 |
      | 5  | WIP      | 2026-04-17 |            |

  Scenario: Default Forecasted CFD shows 2 months of history
    When I successfully run `predictability-engine viz html_forecasted_cfd cfd_range_data.csv`
    Then a file named "reports/cfd_range_data/forecasted_cfd.html" should exist
    # Default is 2 months. 2026-04-17 − 60 days ≈ 2026-02-16 (first point kept: 2026-02-17).
    And the HTML file "reports/cfd_range_data/forecasted_cfd.html" should have a date on the x-axis within 1 day of "2026-02-17" as the first date

  Scenario: Configurable Forecasted CFD history (1 week)
    When I successfully run `predictability-engine viz html_forecasted_cfd cfd_range_data.csv --forecast-history=1w`
    # 1 week before 2026-04-17 is 2026-04-10
    Then the HTML file "reports/cfd_range_data/forecasted_cfd.html" should have a date on the x-axis within 1 day of "2026-04-10" as the first date

  Scenario: Requested forecast history longer than available data
    # Project starts on 2026-02-01. 3 months (90 days) back would be 2026-01-17 — earlier than any data.
    When I successfully run `predictability-engine viz html_forecasted_cfd cfd_range_data.csv --forecast-history=3m`
    Then the HTML file "reports/cfd_range_data/forecasted_cfd.html" should have a date on the x-axis within 1 day of "2026-02-01" as the first date

  Scenario: Configurable Historical CFD range
    When I successfully run `predictability-engine viz html_cfd cfd_range_data.csv --historical-cfd-history=2w`
    # 2 weeks before 2026-04-17 is 2026-04-03
    Then the HTML file "reports/cfd_range_data/cfd.html" should have a date on the x-axis within 1 day of "2026-04-03" as the first date

  Scenario: Default Historical CFD shows whole range
    When I successfully run `predictability-engine viz html_cfd cfd_range_data.csv`
    Then the HTML file "reports/cfd_range_data/cfd.html" should have a date on the x-axis within 1 day of "2026-02-01" as the first date

  Scenario: Last day is always labeled on the Historical CFD x-axis
    # The weekly major-tick cadence might otherwise skip the last day; the chart
    # must guarantee it is always in the labeled `values` list.
    When I successfully run `predictability-engine viz html_cfd cfd_range_data.csv`
    Then the HTML file "reports/cfd_range_data/cfd.html" should have "2026-04-17" as a labeled x-axis tick

  Scenario: Short 7-day range still carries minor daily ticks and a last-day label
    Given a file named "short.csv" with the following adjusted data:
      | id | title | start_date | end_date   |
      | 1  | A     | 2026-04-11 | 2026-04-12 |
      | 2  | B     | 2026-04-13 | 2026-04-14 |
      | 3  | C     | 2026-04-15 | 2026-04-16 |
      | 4  | D     | 2026-04-16 | 2026-04-17 |
    When I successfully run `predictability-engine viz html_cfd short.csv`
    Then the HTML file "reports/short/cfd.html" should have CFD x-axis with minor ticks and long labeled ticks
    And the HTML file "reports/short/cfd.html" should have "2026-04-17" as a labeled x-axis tick
