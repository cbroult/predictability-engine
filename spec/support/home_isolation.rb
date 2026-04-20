# frozen_string_literal: true

require 'tmpdir'

# Shared context that redirects ~ expansion to a temporary directory for the
# duration of each example. Prevents specs from reading or writing the
# developer's real ~/.config/jira/ directory.
RSpec.shared_context('with isolated home') do
  around do |example|
    Dir.mktmpdir('rspec-home') do |tmp|
      original = Dir.home
      ENV['HOME'] = tmp
      example.run
    ensure
      ENV['HOME'] = original
    end
  end
end
