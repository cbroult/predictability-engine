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

  Scenario: Done items without Resolved use Updated when done_statuses sidecar configured
    Given a file named "jira_export.csv" with:
      """
      Issue key,Summary,Issue Type,Priority,Created,Updated,Resolved,Status
      PROJ-1,Done no resolved,Story,High,2026-01-10,2026-01-25,,Done
      PROJ-2,Properly resolved,Story,High,2026-02-01,2026-02-15,2026-02-15,Done
      """
    And a file named "jira_export.yml" with:
      """
      done_statuses:
        - Done
      """
    When I successfully run `predictability-engine summary jira_export.csv`
    Then the exit status should be 0
    And the output should contain "Total Items"

  Scenario: Shared .predictability_engine.yml supplies done_statuses for any CSV in the working directory
    Given a file named "export_a.csv" with:
      """
      Issue key,Summary,Issue Type,Priority,Created,Updated,Resolved,Status
      PROJ-1,Done item,Story,High,2026-01-10,2026-01-25,,Done
      PROJ-2,WIP item,Story,High,2026-01-10,2026-01-25,,In Progress
      """
    And a file named ".predictability_engine.yml" with:
      """
      jira_csv:
        done_statuses:
          - Done
      """
    When I successfully run `predictability-engine summary export_a.csv`
    Then the exit status should be 0
    And the output should contain "Completed Items: 1"

  Scenario: Workflow YAML statuses format is accepted as done_statuses config in sidecar
    Given a file named "jira_wf.csv" with:
      """
      Issue key,Summary,Issue Type,Priority,Created,Updated,Resolved,Status
      PROJ-1,Done item,Story,High,2026-01-10,2026-01-25,,Done
      PROJ-2,WIP item,Story,High,2026-01-10,2026-01-25,,In Progress
      """
    And a file named "jira_wf.yml" with:
      """
      statuses:
        - name: Done
          category: done
          role: departure
        - name: In Progress
          category: in progress
          role: arrival
      """
    When I successfully run `predictability-engine summary jira_wf.csv`
    Then the exit status should be 0
    And the output should contain "Completed Items: 1"

  Scenario: workflow_config_path in sidecar loads done statuses from a shared workflow file
    Given a file named "jira_ref.csv" with:
      """
      Issue key,Summary,Issue Type,Priority,Created,Updated,Resolved,Status
      PROJ-1,Done item,Story,High,2026-01-10,2026-01-25,,Done
      PROJ-2,WIP item,Story,High,2026-01-10,2026-01-25,,In Progress
      """
    And a file named "team.workflow.yml" with:
      """
      statuses:
        - name: Done
          category: done
          role: departure
        - name: In Progress
          category: in progress
          role: arrival
      """
    And a file named "jira_ref.yml" with:
      """
      workflow_config_path: team.workflow.yml
      """
    When I successfully run `predictability-engine summary jira_ref.csv`
    Then the exit status should be 0
    And the output should contain "Completed Items: 1"

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
