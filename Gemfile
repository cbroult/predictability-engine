# frozen_string_literal: true

source 'https://rubygems.org'

# Use the gemspec for dependencies
gemspec

# Internal cbp-org gems — only available in local dev and internal CI.
# Public GitHub Actions workflows skip this group with BUNDLE_WITHOUT=internal_ci
# while keeping Gemfile and Gemfile.lock dependency resolution stable.
group :internal_ci do
  source 'https://gems.cbp-org.internal' do
    gem 'badge-service-cli'
  end
end
