# frozen_string_literal: true
Feature: URL prefix for item links
  As a user with items tracked in an external tool
  I want to specify a URL prefix so that chart items become clickable links
  So that I can navigate directly from the dashboard to any work item

  Background:
    Given a file named "items.csv" with the following adjusted data:
      | id     | title       | type  | start_date | end_date   |
      | PROJ-1 | First item  | Story | 2026-01-10 | 2026-01-20 |
      | PROJ-2 | Second item | Task  | 2026-01-15 |            |

  Scenario: --url-prefix builds clickable URLs from item IDs
    When I run `predictability-engine viz html_all items.csv --url-prefix https://jira.example.com/browse/`
    Then the exit status should be 0
    And the HTML file "reports/items/dashboard.html" should embed url "https://jira.example.com/browse/PROJ-1" for item "PROJ-1"

  Scenario: url_prefix in sidecar YAML builds URLs without a CLI flag
    Given a file named "items.yml" with:
      """
      url_prefix: https://jira.example.com/browse/
      """
    When I run `predictability-engine viz html_all items.csv`
    Then the exit status should be 0
    And the HTML file "reports/items/dashboard.html" should embed url "https://jira.example.com/browse/PROJ-1" for item "PROJ-1"

  Scenario: explicit url field in CSV overrides url_prefix
    Given a file named "items.csv" with:
      """
      id,title,type,start_date,end_date,url
      PROJ-1,First item,Story,2026-01-10,2026-01-20,https://custom.example.com/PROJ-1
      PROJ-2,Second item,Task,2026-01-15,,
      """
    When I run `predictability-engine viz html_all items.csv --url-prefix https://jira.example.com/browse/`
    Then the exit status should be 0
    And the HTML file "reports/items/dashboard.html" should embed url "https://custom.example.com/PROJ-1" for item "PROJ-1"
