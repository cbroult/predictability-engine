# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'cucumber/rake/task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)

Cucumber::Rake::Task.new(:features) do |t|
  t.cucumber_opts = 'features --format pretty'
end

RuboCop::RakeTask.new(:rubocop)

desc 'Run copy-paste detection'
task :jscpd do
  sh 'npx jscpd .'
end

desc 'Run all tests and quality checks'
task default: %i[rubocop spec features jscpd]
