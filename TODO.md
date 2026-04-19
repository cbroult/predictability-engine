# Prepare Jira Projects to support dev and CI workflows

Tests are going to be run in a dev environment and in CI (WP CI and Github Actions).

In each environment, we want 3 projects with differing workflows and items:
* The Big Dog Team
* The Quality Whisperers 
* The Support Team (ITSM like work items and workflows)

Expectations
* Each environment has its dedicated set of projects.
* Across environments, the 3 projects should be the same setup in terms of workflows and items. 
* Sharing workflows, screens,  work items is expected, using Jira's built-in functionality.
* Leverage Jira's built-in functionality to create the projects, workflows and items.
* Use Jira API whenever possible with fallback to Playwright to automate the creation of the items and configure the projects.

Please plan this work, so creating the projects, workflows and items can be done automatically.

# Automatically populate Jira Projects with test data

* Test data should be generated and populated into Jira projects for testing purposes.
* Use Jira API whenever possible with fallback to Playwright to automate the creation of test data and populate Jira projects.
* Ensure that test data is consistent across environments.
* Implement unit tests to validate the test data population process.

# Resolution Handling

* Resolution handling is documented as live documentation in feature file scenarios
* Remove duplication in @cli.rb related to a0-a6, 5k, 4k, hd 
* Refactor @cli.rb to use a common method for handling different resolutions 
* Fail when a specified resolution does not exist
* Implement unit tests for @cli.rb to ensure resolution handling
* Add support for other resolutions in a configuration file

# Fix the logger usage

* The challenge here is that in a log of cases the logger is used to report the results of a call that should be called irrespective of the log level. That means the {} is likely wrong in that case for info level logging.
* Refactor logger usage to ensure proper logging based on log level


# Fix Jira Integration Issues

According to the following investigation:

Now I have successfully found the correct combination:
client.Issue.jql('project = PEDEVTQW', expand: 'changelog', fields: %w[summary issuetype created priority resolutiondate status])
This returns all the fields needed for the predictability engine:- summary -> for work item title
- issuetype -> for work item type- created -> for start_date (or for cycle time calculation)
- priority - for priority- resolutiondate -> for end_date (completion date)
- status - for current status
- changelog - for tracking status transitions
  The current code only passes expand: 'changelog' but doesn't specify fields, which is why the fields are not included.
  The fix is to update the fetch_issues method in lib/predictability_engine/data_sources/jira.rb to include the fields parameter.
  Solution Found
  The correct JQL call requires passing fields as an array (not a string):
# Current (broken):
client.Issue.jql(jql, expand: 'changelog')
# Fixed:
client.Issue.jql(jql, expand: 'changelog', fields: %w[summary issuetype created priority resolutiondate status])
The fields parameter must be an array, not a string
Input
fields: "summary,..." (string)
fields: %w[summary ...] (array)
What fields are returned
- summary → Work item title
- issuetype → Work item type
- created → Start date
- priority → Priority
- resolutiondate → End date
- status → Current status
- changelog → Status transitions (already included)
  The root cause is the code in lib/predictability_engine/data_sources/jira.rb:118-121 only passes expand: 'changelog' but doesn't specify the fields parameter. The jira-ruby gem's jql() method won't return field data unless explicitly requested.

# Improve the naming convention for the Jira projects

* Allow profile.{project_key,filter_name}.yml as convention for naming the configuration files.
* Then modify the code to use this convention.
* Add the corresponding scenarios to the feature files.

# Dead programs tell no lies

Raise an error instead of a warning as per the dead programs tell no lies principle:
```shell
cbroult@darkroom:~/work/ruby/predictability-engine$ ./bin/predictability-engine batch cbroult-atlassian.PEDEVTQW.yml
Warning: Failed to generate terminal report: Failed to load from Jira: undefined method 'summary' for an instance of JIRA::Resource::Issue
Warning: Failed to generate html report: Failed to load from Jira: undefined method 'summary' for an instance of JIRA::Resource::Issue
Warning: Failed to generate pdf report: Failed to load from Jira: undefined method 'summary' for an instance of JIRA::Resource::Issue
Warning: Failed to generate png report: Failed to load from Jira: undefined method 'summary' for an instance of JIRA::Resource::Issue
Warning: Failed to generate md report: Failed to load from Jira: undefined method 'summary' for an instance of JIRA::Resource::Issue
Warning: Failed to generate conf report: Failed to load from Jira: undefined method 'summary' for an instance of JIRA::Resource::Issue
Warning: Failed to generate a3_landscape report: Failed to load from Jira: undefined method 'summary' for an instance of JIRA::Resource::Issue
Warning: Failed to generate ppt report: Failed to load from Jira: undefined method 'summary' for an instance of JIRA::Resource::Issue

```