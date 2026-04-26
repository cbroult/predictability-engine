Feature: Jira HTTP debug logging
  As a developer diagnosing Jira connectivity issues
  I want to enable wire-level HTTP debug output with JIRA_HTTP_DEBUG=true
  So I can see exactly what requests are sent when troubleshooting

  # JIRA_HTTP_DEBUG=true activates jira-ruby's built-in request tracing.
  # It prints  "method: path - [body]"  to stdout before every HTTP call,
  # so the line appears even when the server is unreachable.

  Scenario: JIRA_HTTP_DEBUG=true prints the HTTP method and path before each Jira request
    Given the environment variable "JIRA_SITE" is set to "http://127.0.0.1:19999"
    And the environment variable "JIRA_EMAIL" is set to "debug@example.com"
    And the environment variable "JIRA_API_TOKEN" is set to "fake-token"
    And the environment variable "JIRA_HTTP_DEBUG" is set to "true"
    When I run `predictability-engine summary jira`
    Then the output should contain "get: /rest/api"

  Scenario: Without JIRA_HTTP_DEBUG no request trace is emitted
    Given the environment variable "JIRA_SITE" is set to "http://127.0.0.1:19999"
    And the environment variable "JIRA_EMAIL" is set to "debug@example.com"
    And the environment variable "JIRA_API_TOKEN" is set to "fake-token"
    When I run `predictability-engine summary jira`
    Then the output should not contain "get: /rest/api"
