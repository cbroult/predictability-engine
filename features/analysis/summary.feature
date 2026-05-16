Feature: Summary command
  In order to understand my team's flow metrics
  As a manager
  I want to see a summary of throughput and cycle time

  Scenario: Running summary on sample data
    Given the template CSV file "sample_data.csv" is adjusted to recent dates and saved as "sample_data.csv"
    When I run `predictability-engine summary sample_data.csv`
    Then the exit status should be 0
    And the output should contain "Flow Metrics Summary"
    And the output should contain "Average Throughput: 0.42 items/day"
    And the output should contain "50th Percentile: 7 days"
    And the output should contain "85th Percentile: 11 days"
    And the output should contain "95th Percentile: 12 days"
