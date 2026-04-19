# Plan / TODO

## Workflow-aware arrival/departure statuses

Today the Jira adapter hard-codes what counts as "in progress" via a keyword list
(`In Progress`, `Doing`, `Active`, `Development`, `Progress` — see
`DataSources::Jira#first_in_progress_date`) and the CFD/CT calculators treat
`start_date` / `end_date` as the canonical arrival / departure markers. Real Jira
projects use workflows with varied, team-specific status names and multiple
statuses that may all represent "arrived" or "departed". The fix is to make the
mapping data-driven, extractable from Jira workflows, and composable.

### 1. Extract workflow statuses from Jira

* Call the Jira workflow / project-status endpoints to pull every status that
  any issue in the configured project can transition through.
* For each status capture: `name`, `category` (`to do` / `in progress` / `done`),
  and the workflow(s) it participates in.
* Deduplicate across workflows so each status appears once, with the set of
  workflows that use it.

### 2. Emit an editable YAML mapping

* New command `./bin/predictability-engine jira_workflow <profile>` (or a flag on
  `jira_config`) writes a file like `~/.config/jira/<profile>.workflow.yml`
  with a structure such as:

  ```yaml
  profile: acme
  project: ACME
  statuses:
    - name: "Backlog"
      category: "to do"
      role: null                # user-adjustable: arrival | departure | null
    - name: "In Progress"
      category: "in progress"
      role: arrival
    - name: "Done"
      category: "done"
      role: departure
  ```

* First run seeds sensible defaults from `category` (`in progress` → arrival,
  `done` → departure). User edits the file to override per workflow/team.
* **Re-running the command against an existing file refreshes the snapshot**:
  fetch the current statuses, preserve every role the user already set, add
  any new statuses with seeded-default roles, and drop statuses no longer
  present in the workflow. This keeps the mapping current as Jira workflows
  evolve without clobbering local edits.

### 3. Consume the mapping in the Jira adapter

* Replace the keyword list in `first_in_progress_date` with a lookup against
  the YAML (arrival statuses for start_date, departure statuses for end_date).
* If the mapping is absent, fall back to the current keyword heuristic and
  log a warning pointing the user at `jira_workflow`.

### 4. Project-level config + merged common config

* Support per-project files (`~/.config/jira/<profile>.workflow.yml`).
* Introduce a merge command that composes two or more project configs into a
  shared config file (e.g. `~/.config/jira/common.workflow.yml`): union of
  statuses, with role taken from the first config that assigned one, conflicts
  surfaced as warnings.
* The merged file is just another workflow YAML — it can itself be referenced
  downstream.

### 5. Reference from reports YAML (`*.yml` data source)

* Extend `DataSources::JiraYaml` so a reports query file can point at a
  workflow config:

  ```yaml
  jira_profile: acme
  workflow_config: common.workflow.yml   # or an absolute path
  query: "project in (ACME, BETA) AND sprint in openSprints()"
  ```

* `JiraYaml#resolve` returns `(profile, query, workflow_mapping)`; the Jira
  adapter passes the mapping into the transition scanner.

### 6. Tests

* Unit specs for the workflow extractor (with recorded Jira responses) and the
  merge logic (conflict resolution, precedence).
* Cucumber scenario: a reports YAML referencing a common workflow config
  produces a CFD where a custom "Ready for QA" status is counted as a
  departure.
