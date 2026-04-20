# frozen_string_literal: true

Feature: Monte Carlo Hindcast Calibration
  As a team using Monte Carlo forecasting
  I want to validate how accurate my simulation's percentile claims are
  So I can trust (or correct) the forecast before relying on it

  Scenario: calibrate command on a large dataset succeeds and prints calibration results
    Given the sample file "sample_data_large.csv" is copied into the working directory
    When I successfully run `predictability-engine calibrate sample_data_large.csv --validation-trials 30 --primary-trials 500`
    Then the output should contain "Monte Carlo Hindcast Calibration"
    And the output should contain "Trials run:"

  Scenario: calibrate command on an insufficient dataset prints a graceful message
    Given a file named "tiny.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2025-01-01,2025-01-05
      PROJ-2,Item 2,2025-01-02,2025-01-06
      PROJ-3,Item 3,2025-01-03,2025-01-07
      """
    When I successfully run `predictability-engine calibrate tiny.csv`
    Then the output should contain "Insufficient data"
