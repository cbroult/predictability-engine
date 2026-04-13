# frozen_string_literal: true
require 'simplecov'
require_relative 'support/simplecov_patch'

# SimpleCov is silent by default in sub-processes
SimpleCov.command_name "Cucumber Subprocess #{Process.pid}"
SimpleCov.start do
  enable_coverage :branch
  add_filter '/spec/'
  add_filter '/features/'
  # Ensure we use the same root as the main process
  root File.expand_path('..', __dir__)
end
