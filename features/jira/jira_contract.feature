# frozen_string_literal: true
@real_jira
Feature: JIRA Issue Contract Verification
  As a developer
  I want to verify that JIRA data conforms to our engine's expected contract
  So that I can limit integration risks from API or project-specific changes

  Scenario: Verify JIRA issue fields and changelog structure
    Given a Jira project is seeded with 2 test issues with cleanup
    When I run `predictability-engine viz all_formats jira`
    Then the output should contain "Report generated"
    And the JIRA issue contract should be verified for the seeded project
