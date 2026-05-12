# frozen_string_literal: true

# Runs bin/setup with PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 so no real Chromium
# download occurs in CI. The scenario verifies that bundle install is executed
# *before* the predictability-engine CLI is invoked — the bug this guards
# against is calling `bundle exec predictability-engine` before `bundle install`
# on a fresh clone, which produces "command not found: predictability-engine".
When('I run {command} with PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD set') do |cmd|
  project_root = File.expand_path('../..', __dir__)
  script = File.join(project_root, cmd.to_s)
  set_environment_variable('PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD', '1')
  run_command_and_stop("bash #{script}", exit_timeout: 120)
end

Given('Playwright is already installed and current') do
  # Run npm install in the Aruba working dir so node_modules/.bin/playwright
  # exists before the setup command checks playwright_installed?.
  project_root = File.expand_path('../..', __dir__)
  run_command_and_stop("npm install --prefix #{project_root}", exit_timeout: 60)
end

Given('the PATH does not include npm or node') do
  path_without_node = ENV.fetch('PATH', '')
                         .split(File::PATH_SEPARATOR)
                         .reject { |dir| File.exist?(File.join(dir, 'npm')) || File.exist?(File.join(dir, 'node')) }
                         .join(File::PATH_SEPARATOR)
  set_environment_variable('PATH', path_without_node)
end

Given('the gemspec post-install message is loaded') do
  gemspec_path = File.expand_path('../../predictability-engine.gemspec', __dir__)
  spec = Gem::Specification.load(gemspec_path)
  @post_install_message = spec.post_install_message
end

Then('it should mention {string}') do |text|
  expect(@post_install_message).to include(text)
end
