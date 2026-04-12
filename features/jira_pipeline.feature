# frozen_string_literal: true
@real_jira
Feature: Real Jira Integration Pipeline
  As a CI system
  I want to verify that the engine works correctly against a real Jira instance
  So that I can ensure the integration remains robust

  Scenario: Run engine against freshly seeded Jira project
    Given the Jira project "PIPELINE" is seeded with 5 test issues with cleanup
    When I run `predictability-engine summary "project = PIPELINE"`
    Then the output should contain "Total Items: 5"
    And the output should contain "Completed Items: 1"
