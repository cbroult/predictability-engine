# frozen_string_literal: true

Feature: Priority name normalization
  As a team whose Jira instance uses custom priority names (P0, P1, Critical, Blocker…)
  I want to map those names to canonical ones (Highest, High, Medium, Low, Lowest)
  So that reports sort correctly and sub-dashboards use meaningful, consistent names

  Background:
    Given Jira is mocked for filter "MYTEAM" with items:
      | key    | summary       | issuetype | priority | start_date | end_date   |
      | ITEM-1 | Critical task | Story     | P0       | 2024-03-01 | 2024-03-10 |
      | ITEM-2 | Normal task   | Story     | P1       | 2024-03-02 | 2024-03-08 |
      | ITEM-3 | Low task      | Story     | P2       | 2024-03-03 | 2024-03-06 |

  # ─── Inline aliases ──────────────────────────────────────────────────────────
  # Put priority_aliases: directly in the per-project YAML file.
  # Useful for one-off mappings or projects with unusual priority schemes.

  Scenario: inline priority_aliases normalizes custom priorities in the summary
    Given a file named "myteam.PROJ.yml" with:
      """
      priority_aliases:
        P0: Highest
        P1: High
        P2: Medium
      """
    When I successfully run `predictability-engine summary myteam.PROJ.yml`
    Then the output should contain "Highest"
    And the output should contain "High"
    And the output should contain "Medium"
    And the output should not contain "P0"
    And the output should not contain "P1"

  # ─── Profile-level aliases ───────────────────────────────────────────────────
  # Store aliases once in ~/.config/jira/<profile>.priorities.yml and every
  # project that shares that profile picks them up automatically — no per-file
  # config required.
  #
  # Naming convention: the profile is the first dot-separated segment of the
  # YAML filename, e.g. "myteam" in myteam.PROJ.yml.

  Scenario: profile-level priorities.yml is auto-discovered for all projects
    Given a file named "home/.config/jira/myteam.priorities.yml" with:
      """
      P0: Highest
      P1: High
      P2: Medium
      """
    And a file named "myteam.PROJ.yml" with:
      """
      # no priority_aliases here — resolved from the profile-level file
      """
    When I successfully run `predictability-engine summary myteam.PROJ.yml`
    Then the output should contain "Highest"
    And the output should not contain "P0"

  # ─── Inline overrides profile-level ─────────────────────────────────────────
  # A project can override individual mappings inline without replacing the whole
  # profile-level file.  Profile aliases are the base; inline aliases win.

  Scenario: inline priority_aliases overrides profile-level aliases
    Given a file named "home/.config/jira/myteam.priorities.yml" with:
      """
      P0: Highest
      P1: High
      """
    And a file named "myteam.PROJ.yml" with:
      """
      priority_aliases:
        P1: Medium
      """
    When I successfully run `predictability-engine summary myteam.PROJ.yml`
    Then the output should contain "Highest"
    And the output should contain "Medium"
    And the output should not contain "P1"
