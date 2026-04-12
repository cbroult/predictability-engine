# frozen_string_literal: true
Feature: Sub-report Navigation
  As a user with mixed types of work items
  I want to see separate dashboards for each work item type
  And navigate between them easily in the HTML report

  Background:
    Given a file named "mixed_types.csv" with:
      """
      id,title,type,start_date,end_date
      STORY-1,Implement login,Story,2024-03-01,2024-03-05
      STORY-2,Add search,Story,2024-03-02,2024-03-06
      BUG-1,Fix crash,Bug,2024-03-03,2024-03-04
      TASK-1,Update README,Task,2024-03-04,2024-03-04
      """

  Scenario: Generating reports for mixed types
    When I run `predictability-engine report mixed_types.csv html`
    Then the output should contain "4 reports generated"
    And the following files should exist:
      | reports/mixed_types/dashboard.html   |
      | reports/mixed_types/types/Story.html |
      | reports/mixed_types/types/Bug.html   |
      | reports/mixed_types/types/Task.html  |

  Scenario: Verifying navigation links in the main dashboard
    When I run `predictability-engine report mixed_types.csv html`
    Then the HTML file "reports/mixed_types/dashboard.html" should have navigation links:
      | label | url                | active |
      | All   | dashboard.html     | true   |
      | Story | types/Story.html   | false  |
      | Bug   | types/Bug.html     | false  |
      | Task  | types/Task.html    | false  |

  Scenario: Verifying navigation links in a sub-dashboard
    When I run `predictability-engine report mixed_types.csv html`
    Then the HTML file "reports/mixed_types/types/Story.html" should have navigation links:
      | label | url                | active |
      | All   | ../dashboard.html  | false  |
      | Story | Story.html         | true   |
      | Bug   | Bug.html           | false  |
      | Task  | Task.html          | false  |
