# frozen_string_literal: true

require 'simplecov'
require_relative '../../spec/support/simplecov_patch'
SimpleCov.command_name 'Cucumber'
SimpleCov.start do
  enable_coverage :branch
  add_filter '/spec/'
  add_filter '/features/'
end

require 'aruba/cucumber'

Aruba.configure do |config|
  # Use the absolute path to the bin directory
  config.command_search_paths = [File.expand_path('../../bin', __dir__)]
  config.exit_timeout = 180
end

Before do
  # Add SimpleCov helper for subprocesses
  project_root = File.expand_path('../..', __dir__)
  # We use set_environment_variable which is the Aruba way
  set_environment_variable('RUBYOPT', "-I#{project_root}/spec -rsimplecov_helper #{ENV.fetch('RUBYOPT', nil)}")

  # Redirect ~ to a temp dir inside the Aruba working directory so no CLI subprocess
  # reads or writes the developer's real ~/.config/jira/ directory.
  set_environment_variable('HOME', expand_path('home'))

  # Save process-level MOCK_TODAY so we can restore it after each scenario.
  # The "Given Today is ..." step writes directly to ENV (needed for in-process
  # date-shifting helpers); without save/restore that value leaks into the next
  # scenario and shifts fixture dates to the wrong base date.
  @_saved_mock_today = ENV.fetch('MOCK_TODAY', nil)
end

After do
  if @_saved_mock_today.nil?
    ENV.delete('MOCK_TODAY')
  else
    ENV['MOCK_TODAY'] = @_saved_mock_today
  end
end
