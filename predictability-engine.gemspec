# frozen_string_literal: true

require_relative 'lib/predictability_engine/version'

Gem::Specification.new do |spec|
  spec.name          = 'predictability-engine'
  spec.version       = PredictabilityEngine::VERSION
  spec.authors       = ['cbp-org']
  spec.summary       = 'Actionable Agile Metrics and Monte Carlo forecasting engine'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*.rb', 'bin/*', 'data/samples/*.csv']
  spec.bindir        = 'bin'
  spec.executables   = ['predictability-engine']
  spec.require_paths = ['lib']

  ruby_version = File.read(File.join(__dir__, '.ruby-version')).strip.split('-').last
  spec.required_ruby_version = ">= #{ruby_version}"

  spec.add_dependency 'activesupport'
  spec.add_dependency 'caxlsx'
  spec.add_dependency 'dotenv'
  spec.add_dependency 'jira-ruby'
  spec.add_dependency 'langchainrb'
  spec.add_dependency 'matrix'
  spec.add_dependency 'playwright-ruby-client'
  spec.add_dependency 'powerpoint'
  spec.add_dependency 'prawn'
  spec.add_dependency 'roo'
  spec.add_dependency 'rotp'
  spec.add_dependency 'semantic_logger'
  spec.add_dependency 'thor'
  spec.add_dependency 'tty-table'
  spec.add_dependency 'unicode_plot'
  spec.add_dependency 'vega'
  spec.add_dependency 'webrick'
  spec.add_dependency 'zeitwerk'

  spec.add_development_dependency 'aruba'
  spec.add_development_dependency 'benchmark-ips'
  spec.add_development_dependency 'bundler-audit'
  spec.add_development_dependency 'cucumber'
  spec.add_development_dependency 'gem-release'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rake-gem-maintenance'
  spec.add_development_dependency 'redcarpet'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rake'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'yard'

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.post_install_message = <<~MSG
    ─────────────────────────────────────────────────────────────────
    predictability-engine installed.

    Requires Ruby >= #{ruby_version}. If not installed yet:
      macOS:   brew install rbenv && rbenv install #{ruby_version}
      Linux:   curl -fsSL https://mise.run | sh && mise install
      Windows: https://rubyinstaller.org

    Run the idempotent setup to install Node.js, Playwright, and
    Chromium (required for PDF, PNG, and PPTX report generation):

      predictability-engine setup

    Re-run at any time to upgrade dependencies.
    ─────────────────────────────────────────────────────────────────
  MSG
end
