# Prepare Jira Projects to support dev and CI workflows

Tests are going to be run in a dev environment and in CI (WP CI and Github Actions).

In each environment, we want 3 projects with differing workflows and items:
* The Big Dog Team
* The Quality Whisperers
* The Support Team (ITSM like work items and workflows)

Expectations:
* Each environment has its dedicated set of projects.
* Across environments, the 3 projects should be the same setup in terms of workflows and items.
* Sharing workflows, screens, work items is expected, using Jira's built-in functionality.

Status: setup script done; Jira journey live documentation done (jira_journey.feature).
Remaining: actually run the setup script in each CI environment (WP CI, GitHub Actions).

# Look at further diagrams to include and ways to strengthen the predictability engine

* Look deeper at https://actionableagile.com/books/:
  * the ActionableAgile Metrics for Predictability: 10th Anniversary Edition (https://leanpub.com/aamfp-10th, https://actionableagile.com/books/aamfp/)
  * ActionableAgile Metrics for Predictability Volume II: Advanced Topics (https://actionableagile.com/books/aamfp-vol2/, https://leanpub.com/actionableagilemetricsii)
  * Pitfalls and challenges and things to look for.
