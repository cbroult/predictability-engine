# frozen_string_literal: true
Feature: Jira project setup script
  As a developer seeding test data across environments
  I want to use jira_project_setup.rb to provision and verify Jira projects
  So that each CI environment has isolated, realistic Jira data

  Background:
    Given the Jira project setup script is available

  Scenario: Project key derivation for all environments and teams
    Then the project key for env "dev" and team "TBD" is "PEDEVTBD"
    And the project key for env "dev" and team "TQW" is "PEDEVTQW"
    And the project key for env "dev" and team "TST" is "PEDEVTST"
    And the project key for env "wp" and team "TBD" is "PEWPTBD"
    And the project key for env "gha" and team "TBD" is "PEGHATBD"

  Scenario: teams.yml loads three correctly structured teams
    Then the teams config has 3 teams
    And  each team has abbrev, name, workflow, issue_types, and statuses
    And  each team has at least one arrival and one departure status

  Scenario: DataSeeder distribution bucket assignment
    Given a DataSeeder for project "PEDEVTBD" with count 10
    Then issues 1 through 6 are bucketed as completed
    And  issues 7 through 9 are bucketed as in_progress
    And  issue 10 is bucketed as backlog
