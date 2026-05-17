# Look at further diagrams to include and ways to strengthen the predictability engine

* Look deeper at https://actionableagile.com/books/:
  * the ActionableAgile Metrics for Predictability: 10th Anniversary Edition (https://leanpub.com/aamfp-10th, https://actionableagile.com/books/aamfp/)
  * ActionableAgile Metrics for Predictability Volume II: Advanced Topics (https://actionableagile.com/books/aamfp-vol2/, https://leanpub.com/actionableagilemetricsii)
  * Pitfalls and challenges and things to look for.

# Multi-OS support

## Plaforms

* Windows
* Linux
* Mac
* Docker

Expectations:
* Make sure the solution works on all platforms
* The automated setup script should be able to run on all platforms.
* No scenario should be excluded because of platform limitations in the CI. 
* A scenario that is not systematically run is no longer relevant.

# Performance of batch

Analysis (2026-05-17):

Current flow: `load_items → Report.generate_all → [for each format sequentially: run_report → render → write]`

Formats: `terminal html pdf png md conf ppt raw_csv xlsx` (9 formats × N facet types = ~90 write calls for large datasets).

Bottlenecks:
1. **Playwright browser startup per format**: `with_playwright_page` opens a new browser page for each html/pdf/png/pptx render. For a dataset with 10 facet values × 4 Playwright formats = 40 browser-page opens.
2. **Sequential renders**: all 9 formats run one-by-one even though most are independent.

Options:

| Option | Pros | Cons |
|--------|------|------|
| A. Parallel format generation (Thread) | Fastest wall-clock time | Thread safety risk in Report/Visualizer; Playwright not thread-safe |
| B. Shared Playwright session across formats | Eliminates N-1 browser startups; single-threaded safe | Requires refactoring `with_playwright_page` to accept an existing page |
| C. HTML-first pipeline: render HTML once, reuse page for PDF/PNG/PPTX | No redundant Vega re-renders; safe | Requires all Playwright formats to share one `page.goto` |
| D. Parallel non-Playwright formats only | Safe; low risk | Small speedup (md/xlsx/csv are fast anyway) |

**Recommended: B + C combined** — share one Playwright browser page across all Playwright-based formats within a single batch run; non-Playwright formats stay synchronous. This eliminates the dominant cost (browser startup) without threading complexity.

Implementation is non-trivial (refactor `with_playwright_page` in `report.rb`). Treat as a separate feature task when prioritized.
