Feature: Extra-Large Dataset Reporting
  As a manager of a large team
  I want to ensure the dashboard remains readable and performant even with thousands of items
  In order to maintain visibility into my team's flow metrics at scale

  Scenario: Generating reports for an extra-large dataset
    Given an extra large CSV file named "sample_data_xl.csv" with 4000 completed and 400 in progress items
    When I run `predictability-engine viz all_formats sample_data_xl.csv`
    Then the output should be visible on failure
    And the exit status should be 0
    And the following files should exist:
      | reports/sample_data_xl/dashboard.html |
      | reports/sample_data_xl/dashboard.pdf  |
      | reports/sample_data_xl/dashboard.pptx |
    And the HTML file "reports/sample_data_xl/dashboard.html" should be valid and visible in a browser
    And the file "reports/sample_data_xl/dashboard.pdf" should be a valid PDF
    And the PDF file "reports/sample_data_xl/dashboard.pdf" should have 1 page
