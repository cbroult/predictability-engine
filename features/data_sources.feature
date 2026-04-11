# frozen_string_literal: true
Feature: Data Sources
  As a user
  I want to load data from various sources (CSV, Excel, Jira)
  So that I can use the predictability engine with my existing project data

  Background:
    Given a file named "sample.csv" with:
      """
      id,start_date,end_date
      1,2024-01-01,2024-01-05
      2,2024-01-02,2024-01-08
      3,2024-01-03,
      """

  Scenario: Loading from CSV
    When I run `predictability-engine summary sample.csv`
    Then the output should contain "Total Items: 3"
    And the output should contain "Completed Items: 2"

  Scenario: Loading from Excel
    Given an excel file named "sample.xlsx" with items:
      | id | start_date | end_date   |
      | 1  | 2024-01-01 | 2024-01-05 |
      | 2  | 2024-01-02 | 2024-01-08 |
      | 3  | 2024-01-03 |            |
    When I run `predictability-engine summary sample.xlsx`
    Then the output should contain "Total Items: 3"
    And the output should contain "Completed Items: 2"

  Scenario: Loading from Jira (Mocked)
    Given Jira is mocked for filter "12345" with items:
      | key   | created    | resolutiondate |
      | PROJ-1| 2024-01-01 | 2024-01-05     |
      | PROJ-2| 2024-01-02 |                |
    When I run `predictability-engine summary jira:12345`
    Then the output should contain "Total Items: 2"
    And the output should contain "Completed Items: 1"
