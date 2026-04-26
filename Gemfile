# frozen_string_literal: true

source 'https://rubygems.org'

# Use the gemspec for dependencies
gemspec

# Internal cbp-org gems — only available in local dev and WP CI, not in GitHub Actions.
# JIRA_ENV=gha is set by the GHA jira-integration workflow; skip the source there.
unless ENV['JIRA_ENV'] == 'gha'
  source 'https://gems.cbp-org.internal' do
    gem 'badge-service-cli'
  end
end
