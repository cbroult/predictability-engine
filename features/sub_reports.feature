# frozen_string_literal: true
Feature: Sub-report Navigation
  As a user with mixed types of work items
  I want to see separate dashboards for each work item type
  And navigate between them easily in the HTML report

  Background:
    Given a file named "mixed_types.csv" with the following adjusted data:
      | id      | title           | type  | start_date | end_date   |
      | STORY-1 | Implement login | Story | 2024-03-01 | 2024-03-05 |
      | STORY-2 | Add search      | Story | 2024-03-02 | 2024-03-06 |
      | BUG-1   | Fix crash       | Bug   | 2024-03-03 | 2024-03-04 |
      | TASK-1  | Update README   | Task  | 2024-03-04 | 2024-03-04 |

  Scenario: Generating reports for mixed types
    When I run `predictability-engine report mixed_types.csv html`
    Then the output should contain "4 reports generated"
    And the following files should exist:
      | reports/mixed_types/dashboard.html   |
      | reports/mixed_types/types/Story.html |
      | reports/mixed_types/types/Bug.html   |
      | reports/mixed_types/types/Task.html  |

  Scenario Outline: Verifying navigation links
    When I run `predictability-engine report mixed_types.csv html`
    Then the HTML file "<path>" should have navigation links:
      | label | url                | active   |
      | All   | <all_url>          | <all_a>  |
      | Story | <story_url>        | <story_a>|
      | Bug   | <bug_url>          | <bug_a>  |
      | Task  | <task_url>         | <task_a> |

    Examples:
      | path                                 | all_url           | all_a | story_url        | story_a | bug_url        | bug_a | task_url        | task_a |
      | reports/mixed_types/dashboard.html   | dashboard.html    | true  | types/Story.html | false   | types/Bug.html | false | types/Task.html | false  |
      | reports/mixed_types/types/Story.html | ../dashboard.html | false | Story.html       | true    | Bug.html       | false | Task.html       | false  |
