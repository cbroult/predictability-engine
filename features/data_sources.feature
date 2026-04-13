# frozen_string_literal: true
Feature: Data Sources
  As a user
  I want to load data from various sources (CSV, Excel, Jira)
  So that I can use the predictability engine with my existing project data

  Background:
    Given a file named "sample.csv" with the following adjusted data:
      | id | start_date | end_date   |
      | C1 | 2024-01-01 | 2024-01-05 |
      | C2 | 2024-01-02 | 2024-01-08 |
      | C3 | 2024-01-03 |            |

  Scenario: Loading from CSV
    When I run `predictability-engine summary sample.csv`
    Then the output should contain "Total Items: 3"
    And the output should contain "Completed Items: 2"

  Scenario: Loading from Excel
    Given an excel file named "sample.xlsx" with items:
      | id | start_date | end_date   |
      | E1 | 2024-01-01 | 2024-01-05 |
      | E2 | 2024-01-02 | 2024-01-08 |
      | E3 | 2024-01-03 |            |
    When I run `predictability-engine summary sample.xlsx`
    Then the output should contain "Total Items: 3"
    And the output should contain "Completed Items: 2"

  Scenario: Loading from Jira (Mocked)
    Given Jira is mocked for filter "12345" with items:
      | key   | created    | resolutiondate |
      | J-1   | 2024-01-01 | 2024-01-05     |
      | J-2   | 2024-01-02 |                |
    When I run `predictability-engine summary jira:12345`
    Then the output should contain "Total Items: 2"
    And the output should contain "Completed Items: 1"
