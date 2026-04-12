# JIRA Integration Guide

The Predictability Engine supports direct integration with JIRA using YAML-based source specifications and named credential profiles.

## Setup Credentials

Store your JIRA credentials in `.predictability_engine.yml` in your project root or home directory.

```yaml
jira:
  # Global credentials (fallback)
  site: "https://your-domain.atlassian.net"
  email: "your-email@example.com"
  token: "your-api-token"
  
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

## Creating JIRA Data Sources

Use the `init` command to create a YAML template:

```bash
predictability-engine init my-team.yml
```

### Configuration Options

A JIRA source YAML file supports the following options:

```yaml
jira_profile: prod-instance # Optional: Use specific profile from .predictability_engine.yml
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

To test against a real JIRA instance, you can use the `MOCK_JIRA=false` environment variable and provide valid credentials. For CI/CD, the engine supports network-level recording.
