---
description: Verify the Forecasted CFD confidence-line alignment invariant.
---

Run the alignment-invariant test pair and report pass/fail:

1. `bundle exec rspec spec/predictability_engine/forecast_alignment_spec.rb`
2. `bundle exec cucumber features/forecast_alignment.feature`

Both must pass. If either fails, the invariant described in CLAUDE.md §"Forecast alignment invariant" is broken — fix the **code** (typically `lib/predictability_engine/vega_visualizer/cfd_layout.rb`), NOT the test/feature.

For diagnostics when one fails:
- Extract each rule's `count` from the generated `reports/repro_align/dashboard.html` and compare against `summary[:departed_so_far] + summary[:wip]`.
- `calculate_arrivals_at`-style helpers are a red flag: the rule height must come from the plateau formula directly.
