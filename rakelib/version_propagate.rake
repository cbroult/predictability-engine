# frozen_string_literal: true

require_relative 'erb_processor'

namespace :version do
  desc 'Generate all *.erb templates using the Ruby version from .ruby-version'
  task :propagate do
    ErbProcessor.process_all
  end
end
