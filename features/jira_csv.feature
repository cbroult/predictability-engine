# frozen_string_literal: true

Feature: Jira CSV export as data source
  As a team using Jira
  I want to load a Jira CSV export directly into the predictability engine
  So I can generate flow metrics without a live Jira connection

  Scenario: Jira CSV export loads as a standard dashboard source
    Given a file named "jira_export.csv" with:
      """
      Issue key,Summary,Issue Type,Priority,Created,Resolved
      PROJ-1,Do the thing,Story,High,2026-01-10,2026-01-20
      PROJ-2,Fix the bug,Bug,Medium,2026-02-01,2026-02-15
      """
    When I successfully run `predictability-engine summary jira_export.csv`
    Then the exit status should be 0
    And the output should contain "Total Items"

  Scenario: Jira CSV export with extra columns loads without error
    Given a file named "jira_full.csv" with:
      """
      Issue key,Issue id,Summary,Issue Type,Status,Priority,Reporter,Created,Updated,Resolved
      PROJ-1,10001,Do the thing,Story,Done,High,alice,2026-01-10,2026-01-20,2026-01-20
      PROJ-2,10002,Fix the bug,Bug,Done,Medium,bob,2026-02-01,2026-02-15,2026-02-15
      """
    When I successfully run `predictability-engine summary jira_full.csv`
    Then the exit status should be 0
    And the output should contain "Total Items"
