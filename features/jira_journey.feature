# frozen_string_literal: true

Feature: Jira data source journey
  As a team using Jira
  I want to connect the predictability engine to my Jira instance step by step
  So I can generate flow metrics reports from live Jira data

  # ─── Phase 1 — Store credentials ────────────────────────────────────────────
  # Run once per Jira instance. The command prompts interactively for the site
  # URL, email address, and API token, then stores them under a named profile in
  # ~/.config/jira/jira_credentials.yml (inside fake HOME during tests).

  Scenario: Phase 1 — jira_config stores profile credentials to the home config
    When I run `predictability-engine jira_config my-team` interactively with input "https://my-org.atlassian.net\n\nteam@example.com\nmy-api-token"
    Then the exit status should be 0
    And the output should contain "saved to"
    And a credentials file should exist at "$HOME/.config/jira/jira_credentials.yml"
    And the credentials file should contain profile "my-team"

  Scenario: Phase 1b — jira_config stores context_path for on-premise Jira
    When I run `predictability-engine jira_config on-prem` interactively with input "https://jira.example.com\n/jira\nteam@example.com\nmy-api-token"
    Then the exit status should be 0
    And the output should contain "saved to"
    And the credentials file should contain profile "on-prem" with context_path "/jira"

  # ─── Phase 2 — Create a Jira YAML config file ────────────────────────────────
  # Each data source needs a small YAML file. `init` creates a commented template.
  # By convention, naming it <profile>.<PROJECT_KEY>.yml auto-resolves both the
  # profile and the JQL query without requiring explicit settings.

  Scenario: Phase 2 — init creates a Jira YAML config template
    When I successfully run `predictability-engine init my-team.MYPROJ`
    Then the file "my-team.MYPROJ.yml" should exist
    And the file "my-team.MYPROJ.yml" should contain "jira_profile"
    And the file "my-team.MYPROJ.yml" should contain "project:"
    And the file "my-team.MYPROJ.yml" should contain "filter_id:"

  Scenario: Phase 2b — all-caps middle segment resolves to a combined project+filter query
    Given a file named "my-team.MYPROJ.yml" with:
      """
      # no explicit settings — profile and query derived from filename
      """
    Then the Jira profile for "my-team.MYPROJ.yml" is "my-team"
    And the Jira query for "my-team.MYPROJ.yml" matches both project and filter "MYPROJ"

  Scenario: Phase 2c — lowercase middle segment uses filter convention
    Given a file named "my-team.my-filter.yml" with:
      """
      # no explicit settings
      """
    Then the Jira profile for "my-team.my-filter.yml" is "my-team"
    And the Jira query for "my-team.my-filter.yml" is "filter = \"my-filter\""

  # ─── Phase 3 — Extract workflow config (live Jira required) ─────────────────
  # jira_workflow fetches all board statuses from Jira and writes an editable
  # YAML file. You then set role: arrival / departure / null per status.
  # Re-running refreshes the snapshot while preserving your existing role assignments.

  @jira_live
  Scenario: Phase 3 — jira_workflow extracts workflow statuses for a profile
    Given the JIRA_PROFILE environment variable is set
    When I successfully run `predictability-engine jira_workflow $JIRA_PROFILE`
    Then the exit status should be 0
    And the output should contain "workflow"
    And a workflow file should exist at "$HOME/.config/jira/$JIRA_PROFILE.workflow.yml"

  # ─── Phase 4 — Generate metrics and reports (live Jira required) ─────────────
  # With credentials, a YAML config, and optionally a workflow mapping in place,
  # any report command works against the live Jira data.

  @jira_live
  Scenario Outline: Phase 4 — <command> works with a Jira YAML config
    Given the JIRA_PROFILE environment variable is set
    And a Jira YAML config "jira.yml" exists with the current profile
    When I successfully run `predictability-engine <command> jira.yml`
    Then the exit status should be 0
    And the output should contain "<expected>"

    Examples:
      | command | expected    |
      | summary | Total Items |
      | batch   | terminal    |
