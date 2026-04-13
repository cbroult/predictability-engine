Feature: Extra-Large Dataset Reporting
  As a manager of a large team
  I want to ensure the dashboard remains readable and performant even with thousands of items
  In order to maintain visibility into my team's flow metrics at scale

  Scenario: Scaling visualization for huge datasets
    Given an extra large CSV file named "huge_data.csv" with 4000 completed and 400 in progress items
    When I run `predictability-engine viz all_formats huge_data.csv`
    Then the exit status should be 0
    And the following files should exist:
      | reports/huge_data/dashboard.html |
      | reports/huge_data/dashboard.pdf  |
      | reports/huge_data/dashboard.pptx |
    And the HTML file "reports/huge_data/dashboard.html" should be valid and visible in a browser
    And the file "reports/huge_data/dashboard.pdf" should be a valid PDF
    And the PDF file "reports/huge_data/dashboard.pdf" should have 1 page
