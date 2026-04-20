# frozen_string_literal: true

Feature: predictability-engine setup command
  As a developer or CI pipeline setting up the predictability engine
  I want a single cross-platform command that installs all dependencies
  So I never have to remember which package managers to invoke manually

  # ─── Bundle install ──────────────────────────────────────────────────────────
  # The setup command runs `bundle install` first so Ruby gems are always
  # current. Use --skip-bundle when gems are already in place (e.g. after a
  # fast CI cache restore) to save time.
  #
  # bin/setup (the Linux/macOS/CI shim) must run `bundle install` *before*
  # delegating to `predictability-engine setup --skip-bundle`. If that order
  # is reversed, the CLI executable does not yet exist and the command fails
  # with "bundler: command not found: predictability-engine".

  Scenario: bin/setup runs bundle install before invoking the CLI
    When I run `bin/setup` with SKIP_PLAYWRIGHT set
    Then the exit status should be 0
    And the output should contain "Installing Ruby dependencies"
    And the output should contain "Setup complete"

  Scenario: setup with --skip-bundle --skip-playwright exits successfully
    When I successfully run `predictability-engine setup --skip-bundle --skip-playwright`
    Then the exit status should be 0
    And the output should contain "Setup complete"

  Scenario: setup --help documents all flags
    When I successfully run `predictability-engine help setup`
    Then the output should contain "--skip-playwright"
    And the output should contain "--skip-bundle"

  # ─── Playwright + Chromium ───────────────────────────────────────────────────
  # When npm is available, setup runs `npm install`, `npm update playwright`,
  # and `npx playwright install chromium --with-deps` so the browser always
  # matches the installed Playwright version. Running setup again is safe:
  # it updates in place rather than reinstalling from scratch.

  @npm_required
  Scenario: setup installs and updates Playwright when npm is present
    When I successfully run `predictability-engine setup --skip-bundle`
    Then the exit status should be 0
    And the output should contain "Playwright"
    And the output should contain "Setup complete"

  Scenario: setup reports a clear error when npm is not on PATH
    Given the PATH does not include npm
    When I run `predictability-engine setup --skip-bundle`
    Then the exit status should not be 0
    And the output should contain "npm not found"
    And the output should contain "Node.js"

  # ─── Skip Playwright ─────────────────────────────────────────────────────────
  # CI images that pre-bake Chromium (e.g. the Woodpecker verify container)
  # pass --skip-playwright to avoid redundant downloads.

  Scenario: --skip-playwright skips Playwright install and exits successfully
    When I successfully run `predictability-engine setup --skip-bundle --skip-playwright`
    Then the exit status should be 0
    And the output should not contain "Playwright"
    And the output should contain "Setup complete"

  # ─── Post-install prompt ─────────────────────────────────────────────────────
  # When the gem is installed via `gem install predictability-engine`, a
  # post-install message reminds users to run setup. This is the only hook
  # available across the Ruby/npm package-manager boundary.

  Scenario: gemspec post-install message references the setup command
    Given the gemspec post-install message is loaded
    Then it should mention "predictability-engine setup"
    And it should mention "--skip-playwright"
