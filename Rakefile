# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'cucumber/rake/task'
require 'rubocop/rake_task'
require 'yard'

desc 'Bootstrap Ruby deps + Playwright Chromium (idempotent)'
task :setup do
  sh './bin/setup'
end

# Core tasks
RuboCop::RakeTask.new(:rubocop)

RSpec::Core::RakeTask.new(:spec)

Cucumber::Rake::Task.new(:features) do |t|
  t.cucumber_opts = ['-p', 'default']
end

Cucumber::Rake::Task.new(:features_npm) do |t|
  t.cucumber_opts = ['-p', 'npm']
end

Cucumber::Rake::Task.new(:jira_integrated_tests_run) do |t|
  t.cucumber_opts = ['-p', 'jira_live']
end

desc 'Run @jira_live scenarios (skipped when no Jira credentials are configured)'
task :jira_integrated_tests do
  if ENV['JIRA_PROFILE']
    Rake::Task[:jira_integrated_tests_run].invoke
  else
    puts 'Skipping jira_integrated_tests: set JIRA_PROFILE to run @jira_live scenarios'
  end
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
  sh 'npx jscpd . --config .jscpd.json'
  sh 'npx jscpd . --config .jscpd.gherkin.json'
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

# Reports: generate all sample reports
namespace :reports do
  desc 'Generate all sample reports'
  task :generate_samples do
    samples = Dir.glob('data/samples/*.csv')
    samples.each do |sample|
      puts "Generating reports for #{sample}..."
      sh "./bin/predictability-engine batch #{sample}"
    end
  end
end

namespace :publish do
  desc 'Push the built .gem file to rubygems.org'
  task :rubygems do
    require 'rake/gem/maintenance/gem_publisher'
    require 'rake/gem/maintenance/repos'
    gem_file = Dir.glob('*.gem').first
    raise 'No .gem file found — run gem build first' unless gem_file

    Rake::GemMaintenance::GemPublisher.new(
      Rake::GemMaintenance::Repos.rubygems
    ).publish(gem_file)
  end
end

# Aggregation tasks
desc 'Run rubocop + bundler-audit + jscpd'
task lint: %i[rubocop audit jscpd]

desc 'Run lint + spec + features + jira_integrated_tests (fail-fast: style/audit before slow suites)'
task verify: %i[rubocop audit spec features jscpd jira_integrated_tests]

desc 'Alias for verify — mirrors exactly what verify.yml CI runs'
task ci: :verify

# Default is everything (including slow benchmarks and docs)
task default: %i[verify docs bench]

# Gem maintenance (provides version:bump etc.)
begin
  require 'rake/gem/maintenance/install_tasks'
rescue LoadError
  # Will be available after bundle install
end
