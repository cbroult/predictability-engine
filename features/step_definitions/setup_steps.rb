# frozen_string_literal: true

Given('the PATH does not include npm') do
  # Replace PATH with a version that has no npm, keeping everything else
  # so the predictability-engine binary itself is still found.
  path_without_npm = ENV.fetch('PATH', '')
                        .split(File::PATH_SEPARATOR)
                        .reject { |dir| File.exist?(File.join(dir, 'npm')) }
                        .join(File::PATH_SEPARATOR)
  set_environment_variable('PATH', path_without_npm)
end

Given('the gemspec post-install message is loaded') do
  gemspec_path = File.expand_path('../../predictability-engine.gemspec', __dir__)
  spec = Gem::Specification.load(gemspec_path)
  @post_install_message = spec.post_install_message
end

Then('it should mention {string}') do |text|
  expect(@post_install_message).to include(text)
end
