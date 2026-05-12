# frozen_string_literal: true

Feature: predictability-engine setup command
  As a developer or CI pipeline setting up the predictability engine
  I want a single cross-platform command that installs all dependencies
  So I never have to remember which package managers to invoke manually

  # ─── Bootstrap ───────────────────────────────────────────────────────────────
  # bin/setup is the entry point for a fresh checkout. It bootstraps Bundler,
  # then delegates to `predictability-engine setup` which owns all subsequent
  # setup phases (Ruby gems, Node.js, Playwright, git hooks).

  Scenario: bin/setup runs bundle install and delegates to CLI setup
    When I run `bin/setup` with PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD set
    Then the exit status should be 0
    And the output should contain "Installing Ruby dependencies"
    And the output should contain "Setup complete"

  # ─── Help text ───────────────────────────────────────────────────────────────

  Scenario: setup --help documents the command
    When I successfully run `predictability-engine help setup`
    Then the output should contain "setup"
    And the output should contain "Node.js"

  # ─── Playwright idempotency ───────────────────────────────────────────────────
  # Running setup multiple times must be safe and fast. When Playwright is
  # already installed and at the current version, no npm work is done.

  @npm_required
  Scenario: setup reports Playwright is up to date on second run
    Given Playwright is already installed and current
    When I successfully run `predictability-engine setup`
    Then the output should contain "already up to date"
    And the output should contain "Setup complete"

  # ─── Node.js absent ──────────────────────────────────────────────────────────
  # When neither node nor npm is on PATH, setup exits non-zero so the user
  # knows the prerequisite is missing.

  Scenario: setup reports a clear error when npm and node are not on PATH
    Given the PATH does not include npm or node
    When I run `predictability-engine setup`
    Then the exit status should not be 0

  # ─── Post-install prompt ─────────────────────────────────────────────────────

  Scenario: gemspec post-install message references the setup command
    Given the gemspec post-install message is loaded
    Then it should mention "predictability-engine setup"
