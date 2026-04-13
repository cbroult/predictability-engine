# JIRA Integration Pipeline & Seeding

This guide explains how to use the JIRA integration pipeline and seeder script for automated testing and demonstration purposes.

## CI/CD Integration Pipeline

A dedicated Woodpecker pipeline is available in `.woodpecker/jira-integration.yml` to run end-to-end scenarios against a real JIRA instance. It is triggered manually to prevent unnecessary API usage.

To run it, ensure the following secrets are configured in Woodpecker:
- `jira_site`: Your JIRA instance URL (e.g., `https://your-domain.atlassian.net`)
- `jira_email`: The email address for basic auth.
- `jira_api_token`: Your JIRA API token.

The pipeline uses the `scripts/jira_seeder.rb` script to automatically create test issues in a project (defaulting to the `PIPELINE` project key) and then runs the engine against that project to verify correctness.

## Seeding Test Data

If you need to manually seed a JIRA project with test data for demonstration or testing purposes, you can use the seeder script directly:

```bash
ruby scripts/jira_seeder.rb --project MYPROJ --count 10
```

The seeder script will:
1. Connect to your JIRA instance using the configuration in `~/.config/jira/jira_credentials.yml` or environment variables.
2. Create the specified number of issues in the target project.
3. Perform transitions (e.g., to "In Progress" and "Done") with randomized dates to simulate a realistic history.

## Automated Testing

To test against a real JIRA instance locally, you can use the `MOCK_JIRA=false` environment variable and provide valid credentials:

```bash
JIRA_SITE=... JIRA_EMAIL=... JIRA_API_TOKEN=... \
bundle exec cucumber features/jira_pipeline.feature --tags @real_jira
```
