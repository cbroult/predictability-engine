# frozen_string_literal: true
@jira_setup
Feature: Jira project setup script
  As a developer seeding test data across environments
  I want to use jira_project_setup.rb to provision and verify Jira projects
  So that each CI environment has isolated, realistic Jira data

  Background:
    Given the Jira project setup script is available

  Scenario: Project key derivation for all environments and teams
    When I successfully run `bundle exec ruby scripts/jira_project_setup.rb --help`
    Then the project key for env "dev" and team "TBD" is "PEDEVTBD"
    And the project key for env "dev" and team "TQW" is "PEDEVTQW"
    And the project key for env "dev" and team "TST" is "PEDEVTST"
    And the project key for env "wp" and team "TBD" is "PEWPTBD"
    And the project key for env "gha" and team "TBD" is "PEGHATBD"

  Scenario: teams.yml loads three correctly structured teams
    When I successfully run `bundle exec ruby scripts/jira_project_setup.rb --help`
    Then the teams config has 3 teams
    And each team has abbrev, name, workflow, issue_types, and statuses
    And each team has at least one arrival and one departure status

  Scenario: DataSeeder distributes 40 issues as 60% completed, 30% in-progress, 10% backlog
    Given a DataSeeder for project "PEDEVTBD" with count 40
    When I successfully run `bundle exec ruby scripts/jira_project_setup.rb --help`
    Then issues 1 through 24 are bucketed as completed
    And issues 25 through 36 are bucketed as in_progress
    And issues 37 through 40 are bucketed as backlog

  Scenario: running without a command exits with a descriptive error and usage
    When I run `bundle exec ruby scripts/jira_project_setup.rb --count 160 --profile any-profile`
    Then the exit status should not be 0
    And the output should contain "No command specified. Use: setup | teardown | status"
    And the output should contain "Usage: jira-project-setup <setup|teardown|status> [options]"

  @jira_live
  Scenario: setup provisions three projects and seeds issues
    Given the JIRA_PROFILE environment variable is set
    When I successfully run `bundle exec scripts/jira-project-setup setup --env dev --count 5`
    Then the output should contain "Setup complete."
    And the output should contain "PEDEVTBD"
    And the output should contain "PEDEVTQW"
    And the output should contain "PEDEVTST"

  @jira_live
  Scenario: status shows all three projects with issue counts
    Given the JIRA_PROFILE environment variable is set
    And I successfully run `bundle exec scripts/jira-project-setup setup --env dev --count 5`
    When I successfully run `bundle exec scripts/jira-project-setup status --env dev`
    Then the output should contain "PEDEVTBD"
    And the output should contain "PEDEVTQW"
    And the output should contain "PEDEVTST"
    And the output should match /PEDEVTBD\s+.+\s+\d+/

  @jira_live
  Scenario: teardown removes seeded issues
    Given the JIRA_PROFILE environment variable is set
    And I successfully run `bundle exec scripts/jira-project-setup setup --env dev --count 5`
    When I successfully run `bundle exec scripts/jira-project-setup teardown --env dev`
    Then the output should contain "Teardown complete."
    And the output should contain "PEDEVTBD"

