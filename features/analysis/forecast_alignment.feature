# frozen_string_literal: true

Feature: Repro Issue - CFD Forecast Alignment
  In order to have accurate visualizations
  As a project manager
  I want vertical confidence lines to align with the Arrivals surface

  Scenario: Vertical lines must hit the local Arrivals line (the surface)
    Given Today is "2026-04-10"
    And a file named "repro_align.csv" with:
      """
      id,title,start_date,end_date
      D1,Done 1,2026-04-01,2026-04-02
      D2,Done 2,2026-04-01,2026-04-03
      D3,Done 3,2026-04-01,2026-04-04
      W1,W1,2026-04-01,
      W2,W2,2026-04-01,
      W3,W3,2026-04-01,
      W4,W4,2026-04-01,
      W5,W5,2026-04-01,
      F1,F1,2026-04-25,
      """
    When I run `predictability-engine viz html_all repro_align.csv`
    Then the exit status should be 0
    And a file named "reports/repro_align/dashboard.html" should exist
    And the HTML file "reports/repro_align/dashboard.html" should have confidence rules hit the local surface
