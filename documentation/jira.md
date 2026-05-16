# Jira Integration Guide

> Connect the Predictability Engine to Jira in five minutes. Each step below shows the exact command and the exact output you should see — so you can verify you're on the right track at every stage.
>
> **Auto-refresh**: code blocks marked with `<!-- run: ... -->` are regenerated from the live CLI by `bundle exec rake docs:refresh`. If you update the CLI, re-run that task to keep the docs current.

## Table of Contents

- [0. Verify the CLI is installed](#0-verify-the-cli-is-installed)
- [1. Store credentials](#1-store-credentials-run-once-per-jira-instance)
- [2. Create a source config](#2-create-a-yaml-source-config)
- [3. Map workflow statuses](#3-map-workflow-statuses-recommended)
- [4. Run analysis](#4-run-analysis)
- [5. Jira CSV export (no live connection)](#5-jira-csv-export-no-live-connection)
- [6. Troubleshooting](#6-troubleshooting)

---

## 0. Verify the CLI is installed

```bash
gem install predictability-engine
predictability-engine setup   # installs Playwright + Chromium for PDF/PNG/PPTX
```

Confirm the full command list is available (the `Options:` block applies to all commands):

<!-- run: predictability-engine help -->
```shell
$ predictability-engine help
Commands:
  predictability-engine ask_ai SOURCE QUESTION                            # A...
  predictability-engine batch SOURCE                                      # R...
  predictability-engine calibrate SOURCE                                  # V...
  predictability-engine forecast SOURCE BACKLOG_COUNT                     # R...
  predictability-engine generate OUTPUT                                   # G...
  predictability-engine help [COMMAND]                                    # D...
  predictability-engine init FILENAME                                     # C...
  predictability-engine jira_config PROFILE                               # G...
  predictability-engine jira_workflow PROFILE [OUTPUT]                    # E...
  predictability-engine jira_workflow_merge OUTPUT SOURCE1 [SOURCE2 ...]  # M...
  predictability-engine report SOURCE FORMAT [OUTPUT]                     # G...
  predictability-engine setup                                             # I...
  predictability-engine summary SOURCE                                    # L...
  predictability-engine tree                                              # P...
  predictability-engine viz SUBCOMMAND ...ARGS                            # V...

Options:
  [--output-dir=OUTPUT_DIR]  # Output directory for reports
  [--size=SIZE]              # Image size for PNG/PPT reports (5k, 4k, hd, a0, a1, a2, a3, a4, a5, a6)
                             # Default: a4
                             # Possible values: 5k, 4k, hd, a0, a1, a2, a3, a4, a5, a6
  [--log-level=LOG_LEVEL]    # Logging level (debug, info, warn, error)
                             # Default: info
  [--log-file=LOG_FILE]      # Log file path
  [--url-prefix=URL_PREFIX]  # URL prefix for constructing item URLs from IDs (e.g. https://jira.example.com/browse/)

```
<!-- end -->

---

## 1. Store credentials (run once per Jira instance)

Choose the auth mode that matches your Jira setup:

| Mode | When to use |
|------|-------------|
| `basic` (default) | Atlassian Cloud with API token |
| `bearer` | SSO / OAuth bearer token |
| `cookie` | SSO session cookie |
| `mfa_api` | MFA-protected cloud account |
| `mfa_browser` | MFA via browser flow |

<!-- run: skip -->
```shell
$ predictability-engine help jira_config
Usage:
  predictability-engine jira_config PROFILE

Options:
  -a, [--auth-mode=AUTH_MODE]  # Auth mode: basic | bearer | cookie | mfa_api | mfa_browser
                               # Default: basic
  (global options apply — see Section 0)

Generate/Update JIRA credentials in ~/.config/jira/jira_credentials.yml
```
<!-- end -->

### Atlassian Cloud (basic auth)

```shell
$ predictability-engine jira_config my-team
Jira site (e.g., https://your-domain.atlassian.net): https://my-org.atlassian.net
Context path, if any (leave blank for Atlassian Cloud):
Jira email: team@example.com
Jira API token (input masked): ••••••••
Jira credentials for profile 'my-team' saved to ~/.config/jira/jira_credentials.yml
```

The resulting profile in `~/.config/jira/jira_credentials.yml`:

```yaml
profiles:
  my-team:
    site: https://my-org.atlassian.net
    email: team@example.com
    token: <your-api-token>
```

### On-premise Jira with a context path

```shell
$ predictability-engine jira_config on-prem
Jira site (e.g., https://your-domain.atlassian.net): https://jira.corp.example.com
Context path, if any (leave blank for Atlassian Cloud): /jira
Jira email: user@corp.example.com
Jira API token (input masked): ••••••••
Jira credentials for profile 'on-prem' saved to ~/.config/jira/jira_credentials.yml
```

Resulting YAML:
```yaml
profiles:
  on-prem:
    site: https://jira.corp.example.com
    context_path: /jira
    email: user@corp.example.com
    token: <your-api-token>
```

### SSO bearer token

```shell
$ predictability-engine jira_config sso-bearer --auth-mode bearer
Jira site: https://jira.corp.example.com
Bearer token (input masked): ••••••••
Jira credentials for profile 'sso-bearer' saved to ~/.config/jira/jira_credentials.yml
```

### SSO session cookie

```shell
$ predictability-engine jira_config sso-cookie --auth-mode cookie
Jira site: https://jira.corp.example.com
Session cookie (input masked): ••••••••
Jira credentials for profile 'sso-cookie' saved to ~/.config/jira/jira_credentials.yml
```

### CI / environment variables (no file needed)

Skip `jira_config` entirely in CI — set these environment variables and use `jira` as the source:

```bash
export JIRA_SITE=https://my-org.atlassian.net
export JIRA_EMAIL=team@example.com
export JIRA_API_TOKEN=your-token
export JIRA_PROJECT=MYPROJ

predictability-engine summary jira
```

---

## 2. Create a YAML source config

Use `init` to generate a starter template, then customize it:

<!-- run: skip -->
```shell
$ predictability-engine help init
Usage:
  predictability-engine init FILENAME

Create a template YAML file for JIRA source
```
<!-- end -->

### Convention over configuration

The filename drives both the profile and the JQL query — no YAML keys needed for the common case:

| Filename | Resolved profile | Resolved JQL |
|----------|-----------------|--------------|
| `my-team.MYPROJ.yml` | `my-team` | `project = "MYPROJ"` |
| `my-team.my-filter.yml` | `my-team` | `filter = "my-filter"` |
| `my-team.yml` | `my-team` | `filter = "my-team"` |

The generated template shows what you can override:

```yaml
# JIRA Data Source Configuration
# jira_profile: my-team       # Optional: profile name from ~/.config/jira/jira_credentials.yml
# project: MYPROJ             # Optional: JIRA project key
# filter_id: "12345"          # Optional: JIRA filter ID
# filter_name: "My Filter"    # Optional: JIRA filter name
# query: "project = PROJ"     # Optional: direct JQL query
```

Minimal working config (relies entirely on filename convention — no keys needed):

```yaml
# my-team.MYPROJ.yml — profile=my-team, jql=project="MYPROJ" resolved from filename
```

---

## 3. Map workflow statuses (recommended)

By default the engine detects start/end dates from Jira's issue changelog. Mapping your board's statuses explicitly makes the detection deterministic and improves accuracy when boards have non-standard status names.

<!-- run: skip -->
```shell
$ predictability-engine help jira_workflow
Usage:
  predictability-engine jira_workflow PROFILE [OUTPUT]

Extract Jira workflow statuses for PROFILE into an editable YAML mapping
(default: ~/.config/jira/<profile>.workflow.yml). Re-running refreshes the
snapshot while preserving any roles you already set.
```
<!-- end -->

### Step 1 — extract the status snapshot

```shell
$ predictability-engine jira_workflow my-team
Wrote workflow statuses to ~/.config/jira/my-team.workflow.yml
```

The generated file lists every status from your board:

```yaml
# ~/.config/jira/my-team.workflow.yml
profile: my-team
statuses:
  - name: Backlog
    category: to do
    role:               # blank = ignored
  - name: In Progress
    category: in progress
    role:               # set to: arrival
  - name: Code Review
    category: in progress
    role:               # set to: arrival
  - name: Done
    category: done
    role:               # set to: departure
```

### Step 2 — assign roles

Edit `~/.config/jira/my-team.workflow.yml` and set `role:` for each status:

| Role | Meaning |
|------|---------|
| `arrival` | Item is now "in flight" — first `arrival` transition = start date |
| `departure` | Item is done — last `departure` transition = end date |
| *(blank)* | Ignored — does not affect metrics |

### Step 3 — re-run to refresh after board changes

Re-running `jira_workflow` is idempotent: it adds new statuses, removes deleted ones, and **preserves roles you already set**:

```shell
$ predictability-engine jira_workflow my-team   # safe to re-run anytime
Wrote workflow statuses to ~/.config/jira/my-team.workflow.yml
```

### Merging multiple projects

When several projects share a common board setup, merge their workflows into one config:

<!-- run: skip -->
```shell
$ predictability-engine help jira_workflow_merge
Usage:
  predictability-engine jira_workflow_merge OUTPUT SOURCE1 [SOURCE2 ...]

Merge multiple workflow configs into a shared config. Each SOURCE is either
a profile name (resolved to ~/.config/jira/<profile>.workflow.yml) or an
explicit path to a workflow YAML file.
```
<!-- end -->

```shell
$ predictability-engine jira_workflow_merge common.workflow.yml team-a team-b
Wrote merged workflow to common.workflow.yml
```

When the same status name appears in both sources with different roles, the first-encountered role wins. A blank role loses to any set role.

---

## 4. Run analysis

Once credentials and (optionally) workflow mapping are in place, any analysis command accepts your `.yml` source file directly. The examples below use the bundled sample data to show exact output format:

### Flow metrics summary

<!-- run: predictability-engine summary data/samples/sample_data.csv -->
```shell
$ predictability-engine summary data/samples/sample_data.csv
Flow Metrics Summary
--------------------
Total Items: 18
Completed Items: 15
Average Throughput: 0.42 items/day

Aging WIP Summary:

  Active WIP: 3 items
  Average WIP Age: 44.0 days
  Oldest Item Age: 46 days

Cycle Time Percentiles:
  50th Percentile: 7 days
  75th Percentile: 11 days
  85th Percentile: 11 days
  95th Percentile: 12 days
  98th Percentile: 12 days


```
<!-- end -->

With a Jira source:

```shell
$ predictability-engine summary my-team.MYPROJ.yml
```

### Monte Carlo forecast

<!-- run: predictability-engine forecast data/samples/sample_data.csv 10 -->
```shell
$ predictability-engine forecast data/samples/sample_data.csv 10
Monte Carlo Simulation Results (When will it be done?)

------------------------------------------------------

Backlog size: 10

Number of trials: 10000



Results:

  50% confidence: Done in 23 days

  75% confidence: Done in 27 days

  85% confidence: Done in 30 days

  95% confidence: Done in 34 days

  98% confidence: Done in 37 days

```
<!-- end -->

### Full dashboard (all formats)

```shell
$ predictability-engine batch my-team.MYPROJ.yml
```

Reports are written to `reports/my-team.MYPROJ/`:
- `dashboard.html` — responsive; includes sub-dashboards grouped by item type
- `dashboard.pdf`, `dashboard.png`, `dashboard.md`, `dashboard.xlsx`, `dashboard.pptx`

Control size and resolution with `--size`:

```shell
$ predictability-engine batch my-team.MYPROJ.yml --size=4k
$ predictability-engine batch my-team.MYPROJ.yml --size=a0
```

Single chart only:

```shell
$ predictability-engine viz --help
```

---

## 5. Jira CSV export (no live connection)

If your team can export from Jira but you cannot (or do not want to) connect the engine directly, use a CSV export instead.

Export from Jira: **Issues → Export → CSV (current fields)**. Ensure the export includes at minimum: `Issue key`, `Issue Type`, `Summary`, `Status`, `Created`, `Resolved`.

```shell
$ predictability-engine summary jira_export.csv
```

### Done-status sidecar

Create a sidecar YAML file with the same basename as the CSV to tell the engine which statuses count as "done":

```yaml
# jira_export.yml
done_statuses:
  - Done
  - Released
  - Closed
```

Or point to your shared workflow config to keep the definition in one place:

```yaml
# jira_export.yml
workflow_config_path: ~/.config/jira/my-team.workflow.yml
```

---

## 6. Troubleshooting

### Debug HTTP traffic

Set `JIRA_HTTP_DEBUG=true` to log every API request and response:

```shell
$ JIRA_HTTP_DEBUG=true predictability-engine summary my-team.MYPROJ.yml 2>&1 | head -20
```

### Common errors

| Error | Likely cause | Fix |
|-------|-------------|-----|
| `Profile 'my-team' not found` | Profile name typo, or `jira_config` not run | Run `predictability-engine jira_config my-team` |
| `Connection refused` / `401 Unauthorized` | Wrong site URL, expired token | Re-run `jira_config` with a fresh API token |
| `No departure status defined` | Workflow YAML has no `role: departure` entry | Edit `~/.config/jira/<profile>.workflow.yml` and set `role: departure` on your "Done" status |
| `undefined method 'resolutiondate'` | CSV export missing the Resolved column and no sidecar YAML | Add a `done_statuses:` sidecar next to the CSV |
| `context_path` redirect loop | On-premise Jira at a sub-path with no `context_path` set | Add `context_path: /jira` to the profile via `jira_config` |

---

## Integration Pipeline & Seeding

For CI/CD integration patterns and seeding Jira projects with test data, see the [Jira Pipeline Documentation](jira_pipeline.md).
