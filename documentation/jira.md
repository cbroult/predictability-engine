# JIRA Integration Guide

The Predictability Engine supports direct integration with JIRA using YAML-based source specifications, JIRA keywords, or environment variables.

## Credential Management

### Global Credentials (`jira_config`)
Use the `jira_config` command to securely store your credentials in `~/.config/jira/jira_credentials.yml`. This is the recommended method for local development.

```bash
./bin/predictability-engine jira_config [profile-name]
```

Example output:
```bash
Jira site (e.g., https://your-domain.atlassian.net): https://my-org.atlassian.net
Context path, if any (e.g., /jira — leave blank for Atlassian Cloud): 
Jira email: team@example.com
Jira API token (input masked): ********
Jira credentials for profile '[profile-name]' saved to ~/.config/jira/jira_credentials.yml
```

### On-Premise Jira with a Sub-Path (`context_path`)

If your Jira server is hosted under a sub-path (e.g. `https://collaboration.example.com/jira`), set `context_path` in your profile. This is required when the server returns a redirect for requests that omit the trailing slash on the context path.

```yaml
# ~/.config/jira/jira_credentials.yml
profiles:
  my-server:
    site: "https://collaboration.example.com"
    context_path: "/jira"
    email: "user@example.com"
    token: "api_token"
```

The `jira_config` command will prompt for this value — leave it blank for Atlassian Cloud (where it is not needed).

### Transparent Configuration (CI/CD)
For GitHub Actions, Woodpecker CI, or environments where files are not easily persisted, use environment variables. The engine will automatically pick these up if no explicit profile is provided:

- `JIRA_SITE`: JIRA instance URL
- `JIRA_CONTEXT_PATH`: Sub-path for on-premise Jira (e.g. `/jira`); not needed for Atlassian Cloud
- `JIRA_EMAIL`: Your JIRA email
- `JIRA_API_TOKEN`: Your JIRA API token
- `JIRA_PROJECT`: Default JIRA project key (e.g., `PROJ`)
- `JIRA_PROFILE`: Default credential profile to use

When these variables are set, you can use the `jira` keyword as a source:
```bash
# Uses JIRA_PROJECT and credentials from environment
./bin/predictability-engine summary jira
```

## Data Sources (YAML)

You can define complex data sources using YAML files. The engine uses **Convention over Configuration** to minimize boilerplate.

### Simple Filter
Create a file named `my-team.yml`. If it's empty, the engine automatically runs `filter = "my-team"`.

### Explicit Specification
You can specify a JQL query or a Filter ID in the YAML file:
```yaml
jql: "project = 'MYPROJ' AND issuetype = 'Story'"
jira_profile: "prod-instance"
```

### Initializing a Project
Use the `init` command to generate a well-commented YAML template:
```bash
./bin/predictability-engine init my-project.yml
```

## JIRA Data Mapping

The engine automatically handles the complex mapping from JIRA issues to the standard `WorkItem` model:

- **Type**: Mapped from the `issuetype` field.
- **Start Date**: Automatically detected by analyzing the issue changelog for the first transition to an "In Progress" status.
- **End Date**: Mapped from the `resolutiondate` or the last transition to a "Done" status.

## Integration Pipeline & Seeding

For technical details on CI/CD integration and seeding JIRA projects with test data, refer to [JIRA Pipeline Documentation](jira_pipeline.md).
