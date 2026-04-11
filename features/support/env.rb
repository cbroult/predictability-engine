# frozen_string_literal: true

require 'aruba/cucumber'

Aruba.configure do |config|
  # Use the absolute path to the bin directory
  config.command_search_paths = [File.expand_path('../../bin', __dir__)]
  config.exit_timeout = 60
end
