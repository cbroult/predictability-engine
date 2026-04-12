# JIRA Data Source Integration Plan

### Goals
- Integrate JIRA as a first-class data source for the Predictability Engine.
- Support both direct JQL queries and JIRA Filters via YAML configuration files.
- Automate report generation in all supported formats (HTML, PDF, MD, PPT) when using JIRA sources.
- Provide automatic sub-dashboards based on work item types.

### Acceptance Criteria
1. **YAML-Driven Configuration**: A YAML file can specify a JQL query, a Filter ID, or a Filter Name.
2. **Convention over Configuration**:
   - If a YAML file is empty, use its basename as the JIRA filter name (e.g., `my-team.yml` -> JQL: `filter = "my-team"`).
   - If the filename matches `profile-name.filter-name.yml`, use `profile-name` for credentials and `filter-name` for the query.
   - If a YAML file specifies a `project`, use `project = "[project]"` (this will fetch both active and completed items).
3. **Shared & Independent Credentials**:
   - Supports multiple JIRA instances via named profiles in `.predictability_engine.yml`.
   - YAML files can explicitly reference a JIRA profile (e.g., `jira_profile: prod-instance`).
   - **Convention over Configuration**: If not specified, the filename convention `profile-name.filter-name.yml` is used to identify both the profile and the filter.
4. **Automated Multi-Format Batch Processing**: A single command (e.g., `predictability-engine run [profile-name].[filter-name].yml --all-formats`) generates reports in HTML, PDF, Markdown, and PowerPoint.
5. **Automatic Sub-Dashboards**:
   - Reports are automatically grouped by `WorkItem#type`.
   - If `type` is missing, items are grouped under "Unspecified".
   - Navigation between sub-dashboards is available in the HTML version.
6. **Intuitive Onboarding**: A CLI command (e.g., `predictability-engine init [name].yml`) creates a template YAML file with common options.
7. **Robust Data Mapping**: Automatic detection of `start_date` based on the first transition to an "In Progress" status, and `end_date` based on resolution or the last transition to "Done".
8. **Consistent Output Structure**: Reports are stored in `reports/[source_name]/` with a standardized directory structure for assets and sub-reports.
9. **Real JIRA Integration Testing**: Cucumber scenarios must execute against a real JIRA instance (or a local containerized equivalent) instead of mocking at the Gherkin step level. To support CI without a persistent JIRA instance, the test suite should support a "recording" mode (e.g., using VCR-like network level mocking) that is refreshed periodically against a real instance.

### Implementation Solutions

#### 1. YAML Configuration & Multi-Instance Support
- **Source Identification**: Enhance `DataSources::Factory` to recognize `.yml` or `.yaml` files as JIRA data source specifications.
- **Credential Profiles**: Refactor `Config` to support a nested structure in `.predictability_engine.yml`:
  ```yaml
  jira:
    profiles:
      client-x: { site: "...", email: "...", token: "..." }
      client-y: { site: "...", email: "...", token: "..." }
  ```
- **Convention**: If the filename follows the `profile-name.filter-name.yml` convention, use `profile-name` to load credentials and `filter-name` as the JIRA filter if `jira_profile` and query are not explicitly set in the YAML.

#### 2. Enhanced JIRA Data Mapping
- **WorkItem Mapping**: Update `DataSources::Jira#map_issue` to:
  - Populate `type` from the JIRA `issuetype` field.
  - Detect `start_date` by inspecting issue history/changelog for transitions to "In Progress" status.
  - Use `resolutiondate` as the default `end_date`, with a fallback to the last transition to a "Done" status.

#### 3. Automatic Sub-dashboards & Navigation
- **Grouping Logic**: In `Report.generate_all`, detect the `type` attribute of `WorkItem`s.
- **Handling Missing Types**: Assign "Unspecified" to `WorkItem`s with no `type` to ensure they are captured.
- **Per-Type Generation**: Automatically create separate report instances for each unique work item type in addition to the aggregate report.
- **HTML Dashboard**: Update the Vega/HTML templates to include a "Type" dropdown or sidebar to switch between sub-reports.

#### 4. CLI Improvements
- **Batch Command**: Implement `--all-formats` in the CLI that loops through all registered visualizers.
- **Init Command**: Add a subcommand `init [filename]` that generates a well-commented YAML template for JIRA sources.

### Implementation Phases

#### Phase 1: Core JIRA YAML & Multi-Instance Integration
1. Update `DataSources::Factory` to detect YAML files.
2. Refactor `Config` to support named JIRA profiles and robust credential loading (Profile > Global > ENV).
3. Implement `DataSources::JiraYaml` to parse configuration and merge with defaults/conventions.

#### Phase 2: Enhanced Data Mapping & History Analysis
1. Update `DataSources::Jira` to fetch issue changelogs for better `start_date` detection.
2. Implement robust `issuetype` and `status` mapping logic.
3. Add unit tests for JIRA history parsing and credential profiles.
4. Add integration tests using a real JIRA instance (e.g., via Docker) or a high-fidelity proxy that ensures network-level integration (e.g., VCR for Ruby), rather than mocking at the Gherkin level. This ensures we test the `jira-ruby` client and our history parsing logic against real API responses.

#### Phase 3: Automatic Sub-reports & UI
1. Update `PredictabilityEngine.run_report` to handle multiple reports and a "Batch" output mode.
2. Modify `Report` to support filtering by work item type and fallback for missing types.
3. Enhance HTML/Vega templates to support navigation between multiple sub-reports.

#### Phase 4: CLI, Documentation & UX
1. Implement `predictability-engine run [source] --all-formats`.
2. Implement `predictability-engine init [name].yml`.
3. Create `README_JIRA.md` with examples of YAML configurations and profile setups.
4. Update the main `README.md`.
