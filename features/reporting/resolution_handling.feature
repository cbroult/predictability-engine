# frozen_string_literal: true
Feature: Resolution handling for PNG/PPT reports
  As a user generating image reports
  I want the CLI to validate the --size option against the supported resolutions
  So that I get a clear error instead of a silent fallback when I mistype a size

  Background:
    Given a file named "sample_data.csv" with the following adjusted data:
      | id  | title  | start_date | end_date   |
      | R-1 | Task A | 2026-03-01 | 2026-03-05 |
      | R-2 | Task B | 2026-03-02 | 2026-03-06 |

  Scenario: Valid size generates a PNG report without error
    When I run `predictability-engine viz png sample_data.csv --size=a4`
    Then the exit status should be 0
    And a file named "reports/sample_data/dashboard.png" should exist

  Scenario: Default size (a4) is used when --size is omitted
    When I run `predictability-engine viz png sample_data.csv`
    Then the exit status should be 0
    And a file named "reports/sample_data/dashboard.png" should exist

  Scenario: Invalid size exits with a descriptive error
    When I run `predictability-engine viz png sample_data.csv --size=invalid`
    Then the exit status should not be 0
    And the output should contain "Expected '--size' to be one of"

  Scenario Outline: All supported sizes are accepted for terminal charts
    When I run `predictability-engine viz scatter sample_data.csv --size=<size>`
    Then the exit status should be 0

    Examples:
      | size |
      | 5k   |
      | 4k   |
      | hd   |
      | a0   |
      | a4   |
      | a6   |
