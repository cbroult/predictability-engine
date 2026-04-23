# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Ruby gem (`predictability-engine`) that calculates Actionable Agile Metrics (Cycle Time, Throughput, WIP, CFD, Aging WIP) and runs Monte Carlo forecasts on work-item data sourced from CSV, Excel, or Jira. Output is a unified `Report` rendered to terminal, HTML dashboard, PDF, PNG, PPTX, Markdown, or Confluence via a shared visualizer pipeline (UnicodePlot / Vega-Lite + Playwright).

Ruby version pinned in `.ruby-version` (currently 4.0.2). Thor-based CLI entry point is `bin/predictability-engine`.

## Commands

Aggregated via Rake (see `Rakefile`):

- `bundle exec rake setup` — **one-stop bootstrap**: installs Ruby gems, updates Playwright to the latest compatible version, and installs/updates the Chromium browser. Re-running is safe and keeps everything current. Equivalent: `./bin/setup`.
- `bundle exec rake verify` — runs `spec features lint` (what CI runs in `.woodpecker/verify.yml`).
- `bundle exec rake` (default) — `verify` + `docs` (YARD) + `bench`; slow.
- `bundle exec rake lint` — rubocop + bundler-audit + jscpd.

Individual suites:

- `bundle exec rspec` — unit tests. Single file/example: `bundle exec rspec spec/predictability_engine/report_spec.rb:42`.
- `bundle exec cucumber` — BDD/acceptance (uses Aruba to invoke the CLI). Single scenario: `bundle exec cucumber features/forecast_alignment.feature:12`. Default opts (from `cucumber.yml`) suppress publish reminders.
- `bundle exec rubocop` — style. Auto-fix: `bundle exec rubocop -A`. **Never relax `.rubocop.yml` to silence an offense** — fix the code.
- `npx jscpd .` — duplicate detection (threshold 0.8%, configured in `.jscpd.json`). **Never ignore findings or change the config**; extract or refactor instead.
- `bundle exec rake bench` — `benchmarks/monte_carlo_benchmark.rb`.
- `bundle exec rake audit` — bundler-audit CVE scan.

Running the CLI against sample data:

```bash
./bin/predictability-engine summary data/samples/sample_data.csv
./bin/predictability-engine batch   data/samples/sample_data.csv      # all formats
./bin/predictability-engine report  data/samples/sample_data.csv html
./bin/predictability-engine forecast data/samples/sample_data.csv 30
```

Regenerate all sample reports: `bundle exec rake reports:generate_samples`.

## Architecture

**Pipeline**: `Cli` (Thor) → `DataManager` → `DataSources::Factory` picks strategy by spec shape → returns `Models::WorkItem`s → `Calculators` / `Simulators::MonteCarlo` → `Report` orchestrates `Visualizer` / `VegaVisualizer` / `SummaryVisualizer` / `PdfVisualizer` / `Report::ImageGenerator` / `Report::TextRenderer` → `ReportGenerator` writes output files.

Key entry points to read first when orienting:

- `lib/predictability_engine.rb` — top-level module API (`load_items`, `run_report`, `format_date`, `today`) and Zeitwerk autoload setup.
- `lib/predictability_engine/cli.rb` — two Thor classes: `Cli` (summary/report/batch/forecast/ask_ai/init/jira_config) and nested `Viz` subcommand for per-chart rendering. `batch` delegates to `Viz#all_formats`.
- `lib/predictability_engine/data_sources/factory.rb` — dispatches to `Csv`, `Excel`, `Jira`, `JiraYaml`, or `Base` by matching the spec (extension, `jira:`/`jql:` prefix, uppercase project key, or `.yml`).
- `lib/predictability_engine/report.rb` + `lib/predictability_engine/report/` — the render dispatcher; `Report.generate_all(items)` returns `{all:, <Type>: ...}` so multi-type datasets produce sub-dashboards. `FORMAT_CONFIG`, `CHART_CONFIG`, `RESOLUTION_CONFIG` live in `report/constants.rb`.
- `lib/predictability_engine/report_generator.rb` — writes reports under `<input_dir>/reports/<basename>/` (e.g. `data/samples/reports/sample_data_large/dashboard.html`); sub-reports land in `types/`. Cleans that directory when `report`/`batch` runs unless `--clean=false`.
- `lib/predictability_engine/agents/` — Langchain ReAct assistant (`ask_ai`), tools wrap the calculators.

Patterns:

- **Strategy** for data sources (`DataSources::Base` subclasses).
- **Unified reporting**: one `Report` instance renders all formats; per-format method `render_<format>` is private on `Report`, resolved via `FORMAT_CONFIG` which also supports aliases (`md`→`markdown`, `conf`→`confluence`, `landscape`/`dashboard`→`html`, `a3_landscape`→`pdf`).
- **Zeitwerk** autoloading — filename must match classname (snake_case ↔ CamelCase).

## Conventions That Are Not Obvious From The Code

Captured from `AGENT.md` (authoritative project guidelines):

- **Date format is ISO `YYYY-MM-DD` everywhere.** Always go through `PredictabilityEngine.format_date` / `format_datetime`. Do not introduce `strftime` variants elsewhere.
- **`PredictabilityEngine.today`** honors `MOCK_TODAY=YYYY-MM-DD`. Tests and deterministic repros rely on it — never call `Date.today`/`Date.current` directly in engine code.
- **CFD color coding is fixed**: Arrivals = blue, Departures = green.
- **Forecast percentiles ≠ cycle-time percentiles.** The Forecasted CFD's confidence rules come from `Calculators::CfdForecaster` — Monte Carlo simulation of backlog depletion ("when will all current WIP be done?"), NOT `Calculators::CycleTime.percentile` ("how long does a single item take?"). Even when CT p95 == CT p98 for a dataset, the backlog forecast typically produces distinct dates because it answers a different question. The chart carries a subtitle reinforcing this; don't "fix" the discrepancy by swapping in cycle-time percentiles.
- **Forecast alignment invariant** — see dedicated section below.
- **Conventional Commits** (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:` …). CI badge pipeline and changelog automation depend on this.
- **Co-author**: when committing, use your own Claude Code signature as the co-author trailer (e.g. `Co-Authored-By: Claude <noreply@anthropic.com>`). The `Junie <junie@jetbrains.com>` trailer seen in prior commits was for the JetBrains Junie agent — do not reuse it for Claude-authored work.
- **Fail-fast**: surface descriptive errors; do not silently swallow exceptions in calculators or simulators.
- **DRY**: jscpd enforces this at 0.8%; the threshold is deliberately strict. If a duplicate is flagged, extract a helper. You are not allowed to update jscpd config unless explicitly authorized.
- **Never duplicate values across code locations.** If a list, preset, or label appears in code (e.g. CLI `enum:`, help text, defaults, fixture counts), derive it from the single authoritative source rather than retyping. Example: the `generate` CLI option's allowed sizes and their preset counts are computed from `PredictabilityEngine::DataGenerator::PRESETS` — not re-listed inline. This applies to jscpd-invisible duplication too (values that match semantically even when they don't match as literal token runs).
- **Logger calls must use the block form**: write `PredictabilityEngine.logger.info { "msg #{var}" }`, not `logger.info("msg #{var}")`. The block is only evaluated when the severity is enabled, so interpolation / `#to_s` work is skipped when the level is disabled. Applies to `info/warn/error/debug`. **Exceptions**: (1) when the message is the return value of a side-effecting call (e.g. a method that writes files), compute it into a local first and pass that local into the block — otherwise the side effect is gated behind the log level; (2) when the call IS the primary output that must always execute (e.g. `Visualizer.send(...)` rendering a terminal chart), use string form so the call is never skipped regardless of log level.

## Forecast alignment invariant

The Forecasted CFD draws a vertical "confidence rule" for every percentile `p`. The **y-axis invariant** codifies where each rule ends:

> For each percentile `p` with plateau day `d_p = today + summary[:"p#{p}"]` and plateau value `plateau = summary[:departed_so_far] + summary[:wip]`, the vertical rule is drawn at `x = d_p`, `y ∈ [0, plateau]`. The rule tip touches the top-right corner of the p% surface — never the live Arrivals line, never a neighbour's date.

The invariant is verified by:

```bash
bundle exec rspec spec/predictability_engine/forecast_alignment_spec.rb
bundle exec cucumber features/forecast_alignment.feature
```

Run the `/verify-alignment` slash-command for the same checks with diagnostics.

If either fails, fix the **code** (typically `lib/predictability_engine/vega_visualizer/cfd_layout.rb`), not the verification. The verification files may be edited freely for refactoring — keep the suite green.

## jscpd configuration invariant

`.jscpd.json`: threshold 0.8%, minLines 2, minTokens 16 (ruby/yaml/etc, no gherkin).
`.jscpd.gherkin.json`: threshold 5%, minLines 5, minTokens 50 (gherkin only).

Do NOT change these values without an explicit `[unlock-jscpd]` token in the commit message. When the token is absent, Claude MUST refuse the edit and cite this section.

## Consecutive logger calls → heredoc

When 2+ consecutive `logger` calls form one logical output block, collapse them into a single call with a squiggly heredoc block.

## External Integrations

- **Jira**: credentials resolved from `~/.config/jira/jira_credentials.yml` (profiles) or `JIRA_SITE`/`JIRA_EMAIL`/`JIRA_API_TOKEN` env vars. `./bin/predictability-engine jira_config <profile>` writes the profile file. See `documentation/jira.md` and `documentation/jira_pipeline.md`.
- **OpenAI** (for `ask_ai` / Langchain assistant): `OPENAI_API_KEY` in `.env` (loaded by `dotenv` in `lib/predictability_engine.rb`).
- **Playwright**: used by `Report#with_playwright_page` for PDF/PNG/PPTX fidelity; falls back to Prawn for PDF if Playwright fails.

## CI

Woodpecker pipelines in `.woodpecker/`:

- `verify.yml` runs `bundle exec rake verify` in `ruby:4.0.2-alpine` with Playwright preinstalled — this is the gate that must stay green.
- `code-quality.yml`, `jira-integration.yml`, `publish.yml`, `predictability-engine.yml` — ancillary; check each before assuming a single pipeline is authoritative.
