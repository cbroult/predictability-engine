Feature: Visualization command
  In order to visually understand my team's flow metrics
  As a manager
  I want to see graphical representations in my terminal

  Scenario: Running viz scatter on sample data
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Implement core,2026-03-01,2026-03-05
      PROJ-2,Fix bug A,2026-03-02,2026-03-04
      """
    When I run `predictability-engine viz scatter sample_data.csv`
    Then the exit status should be 0
    And the output should contain "Cycle Time Scatter Plot"
    And the output should contain "Days since 2026-03-04"

  Scenario: Running viz throughput on sample data
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Implement core,2026-03-01,2026-03-05
      PROJ-2,Fix bug A,2026-03-02,2026-03-04
      """
    When I run `predictability-engine viz throughput sample_data.csv`
    Then the exit status should be 0
    And the output should contain "Throughput Histogram"
    And the output should contain "Items per day"

  Scenario: Running viz cfd on sample data
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Implement core,2026-03-01,2026-03-05
      PROJ-2,Fix bug A,2026-03-02,2026-03-04
      """
    When I run `predictability-engine viz cfd sample_data.csv`
    Then the exit status should be 0
    And the output should contain "Cumulative Flow Diagram"
    And the output should contain "Arrivals"
    And the output should contain "Departures"

  Scenario: Running viz all on sample data
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Implement core,2026-03-01,2026-03-05
      PROJ-2,Fix bug A,2026-03-02,2026-03-04
      """
    When I run `predictability-engine viz all sample_data.csv`
    Then the exit status should be 0
    And the output should contain "Flow Metrics Summary"
    And the output should contain "Cycle Time Percentiles"
    And the output should contain "Cycle Time Scatter Plot"
    And the output should contain "Throughput Histogram"
    And the output should contain "Cumulative Flow Diagram"

  Scenario: Running viz html_all on sample data with naming convention
    Given a file named "my_team_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Implement core,2026-03-01,2026-03-05
      PROJ-2,Fix bug A,2026-03-02,2026-03-04
      """
    When I run `predictability-engine viz html_all my_team_data.csv`
    Then the exit status should be 0
    And the output should contain "Dashboard generated at my_team_data_dashboard.html"
    And a file named "my_team_data_dashboard.html" should exist

  Scenario: Validating HTML output in a browser
    Given a file named "browser_test.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2026-03-01,2026-03-05
      PROJ-2,Item 2,2026-03-02,2026-03-04
      """
    When I run `predictability-engine viz html_all browser_test.csv`
    Then the exit status should be 0
    And the HTML file "browser_test_dashboard.html" should be valid and visible in a browser
    And a file named "browser_test_dashboard.html" should contain "Flow Metrics Summary"
    And a file named "browser_test_dashboard.html" should contain "Cycle Time Scatter Plot"
