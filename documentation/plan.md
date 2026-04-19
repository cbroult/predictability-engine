# Plan / TODO

## Jira Project Setup + Test Data Automation

Tests run in three environments: **dev** (local), **wp** (Woodpecker CI), **gha** (GitHub Actions). Each needs its own isolated set of three Jira projects — one per team persona — sharing the same workflow and item structure. Currently only a single-project seeder (`scripts/jira_seeder.rb`) exists with no environment awareness or workflow provisioning.

Goal: a reproducible, idempotent provisioning script that detects the target environment, creates the three projects (Jira API + Playwright fallback), attaches shared named workflows, seeds realistic test data, and is wired into CI pipelines.

### Project key convention

Format: **`PE{ENV}{TEAM}`** (no separators — Jira reserves `-` for ticket numbers).

| Environment | Big Dog Team | Quality Whisperers | Support Team |
|---|---|---|---|
| `dev` | `PEDEVTBD` | `PEDEVTQW` | `PEDEVTST` |
| `wp`  | `PEWPTBD`  | `PEWPTQW`  | `PEWPTST`  |
| `gha` | `PEGHATBD` | `PEGHATQW` | `PEGHATST` |

`JIRA_ENV` env var selects the row; defaults to `dev`.

### Team configurations + workflows

Defined declaratively in `scripts/jira_project_setup/teams.yml`:

**Big Dog Team (`TBD`)** — Scrum software team
```
Workflow: "PE Big Dog Workflow"
Statuses: To Do → In Development → Code Review → Done
Issue types: Story, Task, Bug
Arrival: [In Development]   Departure: [Done]
```

**Quality Whisperers (`TQW`)** — QA-centric team
```
Workflow: "PE Quality Whisperers Workflow"
Statuses: To Do → Ready for Testing → In Testing → Test Review → Done
Issue types: Story, Bug, Test Case
Arrival: [Ready for Testing]   Departure: [Done]
```

**Support Team (`TST`)** — ITSM style
```
Workflow: "PE Support Team Workflow"
Statuses: New → Triaged → In Progress → Waiting for Customer → Resolved → Closed
Issue types: Incident, Service Request, Problem
Arrival: [In Progress]   Departure: [Resolved, Closed]
```

### Script design (`scripts/jira_project_setup.rb`)

Three classes:

**`WorkflowProvisioner`** — checks/creates shared named workflows via `GET /rest/api/3/workflow/search` + `POST /rest/api/3/workflow`; falls back to Playwright for 403/404. Workflows are shared across environments (created once per Jira instance).

**`ProjectProvisioner`** — checks/creates each `(env × team)` project via `GET /rest/api/3/project/{key}` + `POST /rest/api/3/project`; associates team workflow scheme. Idempotent.

**`DataSeeder`** — seeds N issues per project (default 25) with realistic distribution: ~60 % completed, ~30 % in-progress, ~10 % backlog; `created` dates spread over past 90 days for meaningful CFD/CT data. Extends `scripts/jira_seeder.rb`.

CLI:
```bash
ruby scripts/jira_project_setup.rb setup    [--env dev] [--count 25] [--profile default]
ruby scripts/jira_project_setup.rb teardown [--env dev] [--profile default]
ruby scripts/jira_project_setup.rb status   [--env dev]
```

After provisioning, auto-generates `~/.config/jira/PE{ENV}{TEAM}.workflow.yml` via `JiraWorkflow.write` for each project.

### CI pipeline changes

- `.woodpecker/jira-integration.yml` — replace `seed` step with `setup --env wp --count 25 --profile wp`
- `.github/workflows/jira-integration.yml` — new GHA pipeline, `--env gha`

### Tests

- `spec/.../jira_project_setup_spec.rb` — project key derivation, issue-type distribution, YAML config loading
- `features/jira_project_setup.feature` — mock-mode BDD: `setup` creates correct keys; `status` prints counts

### Critical files

| File | Role |
|---|---|
| `scripts/jira_project_setup.rb` | New: entry point |
| `scripts/jira_project_setup/teams.yml` | New: declarative config |
| `scripts/jira_seeder.rb` | Reuse/extend for DataSeeder |
| `lib/predictability_engine/jira_workflow.rb` | Reuse: `JiraWorkflow.write` |
| `lib/predictability_engine/config.rb` | Reuse: `Config.jira_client` |
| `.woodpecker/jira-integration.yml` | Update |
| `.github/workflows/jira-integration.yml` | New |

### Verification

1. `ruby scripts/jira_project_setup.rb status --env dev` → 3 projects, N items each
2. `ruby scripts/jira_project_setup.rb setup --env dev --count 5` → idempotent re-run succeeds
3. `./bin/predictability-engine summary PEDEVTBD` → report uses generated workflow config
4. `bundle exec rspec spec/.../jira_project_setup_spec.rb` → green
5. `bundle exec cucumber features/jira_project_setup.feature` → green
6. `bundle exec rake verify` → full suite green

---

## Logger fix (small)

`logger.info { Visualizer.send(...) }` in the `Viz` define_method loop gates the chart computation behind log level — the chart won't render at `--log-level=warn`. Since chart output must always happen, drop the block form:

```ruby
# lib/predictability_engine/cli.rb ~line 49
PredictabilityEngine.logger.info Visualizer.send(viz_method, items, color: options[:color])
```

Update CLAUDE.md exception clause to document this case.

---

## Resolution handling (small)

- Derive the size description string from `Report::Constants::RESOLUTION_CONFIG.keys` — remove the 3 literal `"a0-a6, 5k, 4k, hd"` occurrences in `cli.rb`
- Add `enum:` validation so `--size=invalid` raises an error immediately (consistent with the `generate --size` option)
- Add feature-file scenarios as live documentation
- Add unit tests for size validation
