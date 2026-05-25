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
