Feature: Version command
  In order to know what version of predictability-engine I have installed
  As a user
  I want to be able to print the current version

  Scenario: Printing the version
    When I run `predictability-engine version`
    Then the exit status should be 0
    And the output should match /\d+\.\d+\.\d+/

  Scenario: Version appears in help output
    When I run `predictability-engine help`
    Then the exit status should be 0
    And the output should match /predictability-engine \d+\.\d+\.\d+/
