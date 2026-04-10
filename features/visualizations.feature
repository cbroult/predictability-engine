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
    And the output should contain "Dashboard generated at my_team_data_all.html"
    And a file named "my_team_data_all.html" should exist

  Scenario: Validating HTML output in a browser
    Given a file named "browser_test.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2026-03-01,2026-03-05
      PROJ-2,Item 2,2026-03-02,2026-03-04
      """
    When I run `predictability-engine viz html_all browser_test.csv`
    Then the exit status should be 0
    And the HTML file "browser_test_all.html" should be valid and visible in a browser
    And a file named "browser_test_all.html" should contain "Flow Metrics Summary"
    And a file named "browser_test_all.html" should contain "Cycle Time Scatter Plot"

  Scenario: Running viz forecasted_cfd on sample data
    Given a file named "wip_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Done 1,2026-03-01,2026-03-05
      PROJ-2,Done 2,2026-03-02,2026-03-04
      PROJ-3,WIP 1,2026-03-05,
      PROJ-4,WIP 2,2026-03-06,
      """
    When I run `predictability-engine viz forecasted_cfd wip_data.csv`
    Then the exit status should be 0
    And the output should contain "Forecasted Cumulative Flow Diagram"
    And the output should contain "50% Confidence"
    And the output should contain "85% Confidence"
    And the output should contain "95% Confidence"

  Scenario: Running viz html_forecasted_cfd on sample data
    Given a file named "wip_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Done 1,2026-03-01,2026-03-05
      PROJ-2,Done 2,2026-03-02,2026-03-04
      PROJ-3,WIP 1,2026-03-05,
      PROJ-4,WIP 2,2026-03-06,
      """
    When I run `predictability-engine viz html_forecasted_cfd wip_data.csv`
    Then the exit status should be 0
    And a file named "wip_data_forecasted_cfd.html" should exist
    And the HTML file "wip_data_forecasted_cfd.html" should be valid and visible in a browser
    And a file named "wip_data_forecasted_cfd.html" should contain "Flow Metrics Summary"

  Scenario: Running viz all with color enabled
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2026-03-01,2026-03-05
      """
    When I run `predictability-engine viz all sample_data.csv --color`
    Then the exit status should be 0
    And the output should contain ANSI color codes

  Scenario: Running viz all with color disabled
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2026-03-01,2026-03-05
      """
    When I run `predictability-engine viz all sample_data.csv --no-color`
    Then the exit status should be 0
    And the output should not contain ANSI color codes

  Scenario: Running report with color enabled
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2026-03-01,2026-03-05
      """
    When I run `predictability-engine report sample_data.csv terminal --color`
    Then the exit status should be 0
    And the output should contain ANSI color codes

  Scenario: Running report with color disabled
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2026-03-01,2026-03-05
      """
    When I run `predictability-engine report sample_data.csv terminal --no-color`
    Then the exit status should be 0
    And the output should not contain ANSI color codes

  Scenario: Running summary with color enabled
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2026-03-01,2026-03-05
      """
    When I run `predictability-engine summary sample_data.csv --color`
    Then the exit status should be 0
    And the output should contain ANSI color codes

  Scenario: Running summary with color disabled
    Given a file named "sample_data.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2026-03-01,2026-03-05
      """
    When I run `predictability-engine summary sample_data.csv --no-color`
    Then the exit status should be 0
    And the output should not contain ANSI color codes

  Scenario: Dynamic verification of HTML report updates
    Given a file named "dynamic_test.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2026-03-01,2026-03-02
      PROJ-2,Item 2,2026-03-01,2026-03-02
      PROJ-3,Item 3,2026-03-01,2026-03-02
      PROJ-4,Item 4,2026-03-01,2026-03-02
      PROJ-5,Item 5,2026-03-01,2026-03-02
      """
    When I run `predictability-engine viz html_all dynamic_test.csv`
    Then the exit status should be 0
    And a file named "dynamic_test_all.html" should contain "Total Items:</strong> 5"
    Given a file named "dynamic_test.csv" with:
      """
      id,title,start_date,end_date
      PROJ-1,Item 1,2026-03-01,2026-03-02
      PROJ-2,Item 2,2026-03-01,2026-03-02
      PROJ-3,Item 3,2026-03-01,2026-03-02
      PROJ-4,Item 4,2026-03-01,2026-03-02
      PROJ-5,Item 5,2026-03-01,2026-03-02
      PROJ-6,Item 6,2026-03-01,2026-03-02
      PROJ-7,Item 7,2026-03-01,2026-03-02
      PROJ-8,Item 8,2026-03-01,2026-03-02
      PROJ-9,Item 9,2026-03-01,2026-03-02
      PROJ-10,Item 10,2026-03-01,2026-03-02
      """
    When I run `predictability-engine viz html_all dynamic_test.csv`
    Then the exit status should be 0
    And a file named "dynamic_test_all.html" should contain "Total Items:</strong> 10"
