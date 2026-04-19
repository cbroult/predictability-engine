# frozen_string_literal: true
Feature: Jira Workflow Status Mapping
  As an analyst tracking several Jira projects across one or more Jira instances
  I want to extract, customise, and merge per-project workflow status configs
  So that my Jira reports use the correct arrival and departure statuses
  without hard-coding assumptions about each team's board configuration

  # ─── Layer 1: Per-project workflow (extraction simulated by pre-written files) ───

  Scenario: Single-source merge writes all statuses unchanged to output
    Given the following workflow config at "solo.workflow.yml":
      """
      profile: solo
      project: SOLO
      statuses:
        - name: In Progress
          category: in progress
          role: arrival
        - name: Done
          category: done
          role: departure
      """
    When I run `predictability-engine jira_workflow_merge merged.workflow.yml solo.workflow.yml`
    Then the exit status should be 0
    And the merged workflow file "merged.workflow.yml" should include these statuses:
      | In Progress | arrival   |
      | Done        | departure |

  Scenario: Refresh preserves user-set roles when the project adds a new status
    Given the following workflow config at "existing.workflow.yml":
      """
      profile: myproject
      project: PROJ
      statuses:
        - name: In Progress
          category: in progress
          role: arrival
        - name: Done
          category: done
          role: departure
      """
    And the following workflow config at "fresh.workflow.yml":
      """
      profile: myproject
      project: PROJ
      statuses:
        - name: In Progress
          category: in progress
          role: arrival
        - name: QA Review
          category: in progress
          role: arrival
        - name: Done
          category: done
          role: departure
      """
    When I refresh the workflow at "existing.workflow.yml" with fresh statuses from "fresh.workflow.yml" writing to "refreshed.workflow.yml"
    Then the merged workflow file "refreshed.workflow.yml" should include these statuses:
      | In Progress | arrival   |
      | QA Review   | arrival   |
      | Done        | departure |

  Scenario: Refresh drops statuses that disappeared from Jira
    Given the following workflow config at "old.workflow.yml":
      """
      profile: proj
      project: PROJ
      statuses:
        - name: In Progress
          category: in progress
          role: arrival
        - name: Obsolete
          category: in progress
          role: arrival
        - name: Done
          category: done
          role: departure
      """
    And the following workflow config at "new.workflow.yml":
      """
      profile: proj
      project: PROJ
      statuses:
        - name: In Progress
          category: in progress
          role: arrival
        - name: Done
          category: done
          role: departure
      """
    When I refresh the workflow at "old.workflow.yml" with fresh statuses from "new.workflow.yml" writing to "pruned.workflow.yml"
    Then the merged workflow file "pruned.workflow.yml" should include these statuses:
      | In Progress | arrival   |
      | Done        | departure |
    And the workflow file "pruned.workflow.yml" should not include a status named "Obsolete"

  # ─── Layer 2: Common config (merge across projects / Jira instances) ───

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
    Then the exit status should be 0
    And the merged workflow file "common.workflow.yml" should include these statuses:
      | In Progress | arrival |
      | Review      | arrival |
      | Shared      | arrival |

  Scenario: Merge three project workflow configs collects all unique statuses
    Given the following workflow config at "alpha.workflow.yml":
      """
      profile: alpha
      project: ALPHA
      statuses:
        - name: Backlog
          category: to do
          role:
        - name: In Progress
          category: in progress
          role: arrival
      """
    And the following workflow config at "beta.workflow.yml":
      """
      profile: beta
      project: BETA
      statuses:
        - name: In Progress
          category: in progress
          role: arrival
        - name: Review
          category: in progress
          role: arrival
      """
    And the following workflow config at "gamma.workflow.yml":
      """
      profile: gamma
      project: GAMMA
      statuses:
        - name: Review
          category: in progress
          role: arrival
        - name: Done
          category: done
          role: departure
      """
    When I run `predictability-engine jira_workflow_merge common.workflow.yml alpha.workflow.yml beta.workflow.yml gamma.workflow.yml`
    Then the exit status should be 0
    And the merged workflow file "common.workflow.yml" should include these statuses:
      | Backlog     |           |
      | In Progress | arrival   |
      | Review      | arrival   |
      | Done        | departure |

  Scenario: Merge adopts a role when one project has none set for that status
    Given the following workflow config at "unset.workflow.yml":
      """
      profile: unset
      project: UNSET
      statuses:
        - name: Review
          category: in progress
          role:
      """
    And the following workflow config at "setter.workflow.yml":
      """
      profile: setter
      project: SETTER
      statuses:
        - name: Review
          category: in progress
          role: arrival
      """
    When I run `predictability-engine jira_workflow_merge result.workflow.yml unset.workflow.yml setter.workflow.yml`
    Then the exit status should be 0
    And the merged workflow file "result.workflow.yml" should include these statuses:
      | Review | arrival |

  Scenario: Merge with a missing source file exits with a descriptive error
    When I run `predictability-engine jira_workflow_merge output.workflow.yml nonexistent.workflow.yml`
    Then the exit status should not be 0
    And the output should contain "Workflow not found"

  # ─── Layer 3: Common config drives Jira report (arrival / departure names) ───

  Scenario: Merged config exposes the correct arrival and departure names
    Given the following workflow config at "project.workflow.yml":
      """
      profile: project
      project: PROJ
      statuses:
        - name: In Progress
          category: in progress
          role: arrival
        - name: Code Review
          category: in progress
          role: arrival
        - name: Done
          category: done
          role: departure
        - name: Closed
          category: done
          role: departure
        - name: Backlog
          category: to do
          role:
      """
    When I run `predictability-engine jira_workflow_merge full.workflow.yml project.workflow.yml`
    Then the exit status should be 0
    And the workflow file "full.workflow.yml" should have arrival names:
      | In Progress |
      | Code Review |
    And the workflow file "full.workflow.yml" should have departure names:
      | Done   |
      | Closed |

  Scenario: Report using common workflow config loads the expected arrival and departure names
    Given the following workflow config at "common.workflow.yml":
      """
      profile: common
      statuses:
        - name: In Development
          category: in progress
          role: arrival
        - name: In Review
          category: in progress
          role: arrival
        - name: Released
          category: done
          role: departure
        - name: Closed
          category: done
          role: departure
      """
    When I load the workflow from "common.workflow.yml"
    Then the workflow arrival names should be "In Development" and "In Review"
    And the workflow departure names should be "Released" and "Closed"
