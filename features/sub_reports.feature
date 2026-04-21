# frozen_string_literal: true
Feature: Sub-report Navigation
  As a user with mixed types of work items
  I want to see separate dashboards for each work item type
  And navigate between them easily in the HTML report

  Background:
    Given a file named "mixed_types.csv" with the following adjusted data:
      | id      | title           | type  | priority | start_date | end_date   |
      | STORY-1 | Implement login | Story | High     | 2024-03-01 | 2024-03-05 |
      | STORY-2 | Add search      | Story | Low      | 2024-03-02 | 2024-03-06 |
      | BUG-1   | Fix crash       | Bug   | High     | 2024-03-03 | 2024-03-04 |
      | TASK-1  | Update README   | Task  | Low      | 2024-03-04 | 2024-03-04 |

  Scenario: Generating reports for mixed types and priorities
    When I run `predictability-engine report mixed_types.csv html`
    Then the output should contain "6 reports generated"
    And the following files should exist:
      | reports/mixed_types/dashboard.html        |
      | reports/mixed_types/types/Story.html      |
      | reports/mixed_types/types/Bug.html        |
      | reports/mixed_types/types/Task.html       |
      | reports/mixed_types/priorities/High.html  |
      | reports/mixed_types/priorities/Low.html   |

  Scenario Outline: Verifying navigation links across facets
    When I run `predictability-engine report mixed_types.csv html`
    Then the HTML file "<path>" should have navigation links:
      | label | url         | active   |
      | All   | <all_url>   | <all_a>  |
      | Story | <story_url> | <story_a>|
      | Bug   | <bug_url>   | <bug_a>  |
      | Task  | <task_url>  | <task_a> |
      | High  | <high_url>  | <high_a> |
      | Low   | <low_url>   | <low_a>  |

    Examples:
      | path                                         | all_url           | all_a | story_url          | story_a | bug_url          | bug_a | task_url          | task_a | high_url               | high_a | low_url                | low_a |
      | reports/mixed_types/dashboard.html           | dashboard.html    | true  | types/Story.html   | false   | types/Bug.html   | false | types/Task.html   | false  | priorities/High.html   | false  | priorities/Low.html    | false |
      | reports/mixed_types/types/Story.html         | ../dashboard.html | false | Story.html         | true    | Bug.html         | false | Task.html         | false  | ../priorities/High.html| false  | ../priorities/Low.html | false |
      | reports/mixed_types/priorities/High.html     | ../dashboard.html | false | ../types/Story.html| false   | ../types/Bug.html| false | ../types/Task.html| false  | High.html              | true   | Low.html               | false |

  Scenario: priority_aliases in YAML config normalizes custom priority names
    Given Jira is mocked for filter "MYTEAM" with items:
      | key    | summary      | issuetype | priority | start_date | end_date   |
      | ITEM-1 | First task   | Story     | P0       | 2024-03-01 | 2024-03-05 |
      | ITEM-2 | Second task  | Story     | P1       | 2024-03-02 | 2024-03-06 |
      | ITEM-3 | Third task   | Story     | P2       | 2024-03-03 | 2024-03-07 |
    And a file named "alias_config.yml" with:
      """
      priority_aliases:
        P0: Highest
        P1: High
        P2: Medium
      """
    When I run `predictability-engine report alias_config.yml html`
    Then the following files should exist:
      | reports/alias_config/priorities/Highest.html |
      | reports/alias_config/priorities/High.html    |
      | reports/alias_config/priorities/Medium.html  |
