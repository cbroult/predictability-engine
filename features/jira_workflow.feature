# frozen_string_literal: true
Feature: Jira Workflow Status Mapping
  As an analyst tracking several Jira projects
  I want to merge per-project workflow status configs into a shared mapping
  So that my reports YAMLs can reference one authoritative arrival/departure vocabulary

  Scenario: Merge two project workflow configs with a role conflict
    Given the following workflow config at "team-a.workflow.yml":
      """
      profile: team-a
      project: TEAMA
      statuses:
        - name: In Progress
          category: in progress
          role: arrival
        - name: Shared
          category: in progress
          role: arrival
      """
    And the following workflow config at "team-b.workflow.yml":
      """
      profile: team-b
      project: TEAMB
      statuses:
        - name: Review
          category: in progress
          role: arrival
        - name: Shared
          category: done
          role: departure
      """
    When I run `predictability-engine jira_workflow_merge common.workflow.yml team-a.workflow.yml team-b.workflow.yml`
    Then the merged workflow file "common.workflow.yml" should include these statuses:
      | In Progress | arrival   |
      | Review      | arrival   |
      | Shared      | arrival   |
