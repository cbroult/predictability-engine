# Plan / TODO

## Commit Optimisation: HTML-only Sample Reports

### Problem

The pre-commit hook regenerates all report formats (PDF, PNG, PPTX, XLSX, CSV,
conf, Markdown, images) on every commit. Binary formats are non-deterministic
(differ each run due to embedded timestamps), causing ~100 files of churn per
commit, slow hooks, and bloated git history.

### Solution

Only commit the HTML dashboard files. HTML output is deterministic (same data →
same markup), small, and viewable directly from the repository browser. All
other formats remain generated locally by the `batch` command but are excluded
from git tracking.

### Changes

| File | Change |
|------|--------|
| `.git/hooks/pre-commit` | `git add` scoped to `'data/samples/reports/**/*.html'` |
| `.gitignore` | Excludes `*.pdf`, `*.png`, `*.pptx`, `*.xlsx`, `*.csv`, `*.conf`, `*.md`, and `*/images/` under `data/samples/reports/` |
| `README.md` | Showcase section links to the HTML dashboard instead of embedding a PNG |

### Viewing the Full Dashboard

The committed HTML dashboards are self-contained (Vega-Lite + inline JSON) and
render correctly when opened from the repository file browser or cloned locally:

```
open data/samples/reports/sample_data_large/dashboard.html
```

For CI-generated dashboards (different datasets, ephemeral), attach them as
Woodpecker pipeline artifacts so they can be downloaded without living in git.

### Status

Implemented in `chore(reports): only commit HTML dashboards, drop binary formats`.

---

## README Link Checker in `verify`

### Problem

The README references several relative file links (e.g. the HTML dashboard, JIRA
docs, ARCHITECTURE.md). These can silently break when files are renamed or deleted.
The HTML dashboard link is particularly important because it is the primary showcase
entry point.

### Options

| Option | Tool | Pros | Cons |
|--------|------|------|------|
| **A — markdown-link-check (npm)** | `npx markdown-link-check README.md` | Widely used, checks anchors + external + relative; available anywhere Node is present; zero config needed | Slower on external URLs (rate limits); needs network for external checks; requires `--no-progress` flag in CI |
| **B — lychee (Rust binary)** | `lychee README.md` | Very fast, parallel, built-in caching, offline-friendly; excellent anchor checking | Extra binary to install; not in typical Ruby CI image |
| **C — mdfmt / custom grep** | Shell `grep` + `test -f` | Zero deps, works in any shell | Fragile, misses anchors, hard to maintain |
| **D — mdl / markdownlint** | `bundle exec mdl` or `npx markdownlint-cli` | Already in CI lint flow if added | Does not check link targets — only validates syntax |

### Recommendation: Option A — `markdown-link-check`

`markdown-link-check` is the pragmatic choice: it is already available in the CI
environment (Node.js + Playwright image), covers relative file paths and internal
anchors, and needs no additional binary install. Use `--quiet` to suppress passing
lines and `--config .markdown-link-check.json` to skip external badge URLs (badges
and internal `cbp-org.internal` URLs are unreachable from CI).

#### Implementation

1. Add `.markdown-link-check.json` to the repo root:
   ```json
   {
     "ignorePatterns": [
       { "pattern": "^https?://badge\\.cbp-org\\.internal" },
       { "pattern": "^https?://ci\\.cbp-org\\.internal" },
       { "pattern": "^https?://github\\.com/cbroult/predictability-engine/actions" }
     ],
     "aliveStatusCodes": [200, 206]
   }
   ```

2. Add a Rake task in `Rakefile`:
   ```ruby
   desc 'Check all links in README.md'
   task :linkcheck do
     sh 'npx --yes markdown-link-check README.md --quiet --config .markdown-link-check.json'
   end
   ```

3. Add `:linkcheck` to the `verify` task dependencies (after `:jscpd`).

#### Caveats

- First run downloads `markdown-link-check` via npx — subsequent runs use the npm
  cache. Pin a version in `package.json` if repeatability matters.
- External links (shields.io, rubygems.org) are checked by default; add them to the
  ignore list if they become flaky in CI.
- Anchor links (`#section-name`) are verified against headings in the file — emoji
  in headings are normalised by GitHub/Forgejo using the same algorithm, so test
  with `--config` rather than relying on exact anchor strings.

### Implemented

`markdown-link-check@3.9.3` (last version compatible with Node 18) with a config that:
- Skips all `https?://` external links (avoids flaky CI due to rate limits/network)
- Skips anchor-only `#` links (GitHub/Forgejo render these dynamically from headings)
- Only checks relative file paths (the primary concern: files must exist)

Files: `.markdown-link-check.json`, `Rakefile` (`:linkcheck` task in `lint` and `verify`).
