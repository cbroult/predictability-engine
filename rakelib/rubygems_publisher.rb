# frozen_string_literal: true

require 'rake/gem/maintenance/gem_publisher'
require 'rake/gem/maintenance/repos'

# Encapsulates the rubygems.org publish flow used by the publish:rubygems Rake task.
# Configures env-var wiring for API key and OTP seed before delegating to GemPublisher.
class RubygemsPublisher
  GEM_FILE_GLOB = '*.gem'
  API_KEY_ENV_VAR = 'GEM_HOST_API_KEY'
  OTP_SEED_ENV_VAR = 'RUBYGEMS_OTP_SEED'

  def self.publish
    configure_repos
    publisher = Rake::Gem::Maintenance::GemPublisher.new(Rake::Gem::Maintenance::Repos.rubygems)
    publisher.publish(gem_file)
    return if publisher.successful_repos.include?('rubygems')

    raise 'Publish to rubygems.org failed — check output above'
  end

  def self.configure_repos
    Rake::Gem::Maintenance::Repos.rubygems_api_key_env_var = API_KEY_ENV_VAR
    Rake::Gem::Maintenance::Repos.rubygems_otp_seed_env_var = OTP_SEED_ENV_VAR
  end

  def self.gem_file
    file = Dir.glob(GEM_FILE_GLOB).first
    raise 'No .gem file found — run gem build first' unless file

    file
  end

  private_class_method :configure_repos, :gem_file
end
