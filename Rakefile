# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'cucumber/rake/task'
require 'rubocop/rake_task'
require 'yard'
require 'yard/rake/yardoc_task'

RSpec::Core::RakeTask.new(:spec)

Cucumber::Rake::Task.new(:features) do |t|
  t.cucumber_opts = %w[features --format pretty --publish-quiet]
end

RuboCop::RakeTask.new(:rubocop)

YARD::Rake::YardocTask.new(:docs) do |t|
  t.options = ['--protected', '--private']
end

desc 'Run copy-paste detection'
task :jscpd do
  sh 'npx jscpd .'
end

desc 'Check dependencies for vulnerabilities'
task :audit do
  sh 'bundle exec bundle-audit check --update'
end

desc 'Run performance benchmarks'
task :bench do
  sh 'ruby benchmarks/monte_carlo_benchmark.rb'
end

desc 'Run all tests and quality checks'
task default: %i[rubocop spec features jscpd audit docs bench]
