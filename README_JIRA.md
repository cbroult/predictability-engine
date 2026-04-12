# JIRA Integration Guide

The Predictability Engine supports direct integration with JIRA using YAML-based source specifications and named credential profiles.

## Setup Credentials

The easiest way to set up your credentials is using the `jira_config` command. It will prompt for your JIRA site, email, and API token and securely store them in `~/.config/jira/jira_credentials.yml`.

```bash
predictability-engine jira_config prod
```

Alternatively, you can manually manage your profiles in `~/.config/jira/jira_credentials.yml`. Profiles in this file take precedence over those in `.predictability_engine.yml`.

```yaml
jira:
  # Named profiles for multiple instances
  profiles:
    client-x:
      site: "https://client-x.atlassian.net"
      email: "consultant@example.com"
      token: "client-x-token"
    prod:
      site: "https://prod.atlassian.net"
      email: "admin@example.com"
      token: "prod-token"
```

> **Note:** When using a profile (e.g., `jira_profile: client-x`), the engine will use those credentials exactly as specified in the profile, with no fallback to environment variables.

## Creating JIRA Data Sources

Use the `init` command to create a YAML template:

```bash
predictability-engine init my-team.yml
```

### Configuration Options

A JIRA source YAML file supports the following options:

```yaml
jira_profile: prod-instance # Optional: Use specific profile from ~/.config/jira/jira_credentials.yml
project: MYPROJ            # Fetch all items in a project
# OR
filter_id: "12345"         # Fetch items from a saved filter
# OR
filter_name: "My Filter"   # Fetch items from a named filter
# OR
query: "project = PROJ AND status = Done" # Custom JQL query
```

### Convention over Configuration

The engine uses filenames to infer configuration if not explicitly provided:

- `my-team.yml` -> JQL: `filter = "my-team"`
- `client-x.my-team.yml` -> Profile: `client-x`, JQL: `filter = "my-team"`

## Generating Reports

Run the `batch` command to generate all report formats at once:

```bash
predictability-engine batch my-team.yml
```

This will generate:
- Terminal summary
- Interactive HTML Dashboard (`reports/my-team/dashboard.html`)
- PDF Dashboard (`reports/my-team/dashboard.pdf`)
- A3 PDF Dashboard (`reports/my-team/dashboard_a3.pdf`)
- Markdown report (`reports/my-team/dashboard.md`)
- Confluence markup (`reports/my-team/dashboard.conf`)
- PowerPoint Dashboard (`reports/my-team/dashboard.pptx`)

### Automatic Sub-Dashboards

If your JIRA items have different `issuetype`s (e.g., Story, Bug, Task), the engine automatically generates sub-dashboards for each type. You can navigate between them in the HTML version using the navigation bar at the top.

## Automated Testing

To test against a real JIRA instance, you can use the `MOCK_JIRA=false` environment variable and provide valid credentials. 

### CI/CD Integration Pipeline

A dedicated Woodpecker pipeline is available in `.woodpecker/jira-integration.yml` to run end-to-end scenarios against a real JIRA instance. It is triggered manually to prevent unnecessary API usage.

To run it, ensure the following secrets are configured in Woodpecker:
- `jira_site`: Your JIRA instance URL (e.g., `https://your-domain.atlassian.net`)
- `jira_email`: The email address for basic auth.
- `jira_api_token`: Your JIRA API token.

The pipeline uses the `scripts/jira_seeder.rb` script to automatically create test issues in a project (defaulting to the `PIPELINE` project key) and then runs the engine against that project to verify correctness.

### Local Integration Testing

You can run the integration tests locally if you have credentials:

```bash
JIRA_SITE=... JIRA_EMAIL=... JIRA_API_TOKEN=... \
bundle exec cucumber features/jira_pipeline.feature --tags @real_jira
```

### Seeding Test Data

If you need to manually seed a JIRA project with test data for demonstration or testing purposes, you can use the seeder script directly:

```bash
ruby scripts/jira_seeder.rb --project MYPROJ --count 10
```
