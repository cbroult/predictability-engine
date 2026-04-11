# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'cucumber/rake/task'
require 'rubocop/rake_task'
require 'yard'

# Core tasks
RuboCop::RakeTask.new(:rubocop)

RSpec::Core::RakeTask.new(:spec)

Cucumber::Rake::Task.new(:features) do |t|
  t.cucumber_opts = ['--publish-quiet', '--format', 'progress']
end

# Security audit
desc 'Check for vulnerable gems'
task :audit do
  require 'bundler/audit/cli'
  Bundler::Audit::Database.update!(quiet: true)
  Bundler::Audit::CLI.start(['check'])
end

# Quality: copy-paste detection
desc 'Run jscpd'
task :jscpd do
  sh 'npx jscpd .'
end

# Quality: documentation
desc 'Generate YARD documentation'
task :docs do
  sh 'bundle exec yard doc'
end

# Performance: benchmarks
desc 'Run benchmarks'
task :bench do
  sh 'ruby benchmarks/monte_carlo_benchmark.rb'
end

# Aggregation tasks
desc 'Run rubocop + bundler-audit + jscpd'
task lint: %i[rubocop audit jscpd]

desc 'Run spec + features + lint'
task verify: %i[spec features lint]

# Default is everything (including slow benchmarks and docs)
task default: %i[verify docs bench]

# Gem maintenance (provides version:bump etc.)
begin
  require 'rake/gem/maintenance/install_tasks'
rescue LoadError
  # Will be available after bundle install
end
