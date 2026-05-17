# Look at further diagrams to include and ways to strengthen the predictability engine

* Look deeper at https://actionableagile.com/books/:
  * the ActionableAgile Metrics for Predictability: 10th Anniversary Edition (https://leanpub.com/aamfp-10th, https://actionableagile.com/books/aamfp/)
  * ActionableAgile Metrics for Predictability Volume II: Advanced Topics (https://actionableagile.com/books/aamfp-vol2/, https://leanpub.com/actionableagilemetricsii)
  * Pitfalls and challenges and things to look for.

# Multi-OS support

## Plaforms

* Windows
* Linux
* Mac
* Docker

Expectations:
* Make sure the solution works on all platforms
* The automated setup script should be able to run on all platforms.
* No scenario should be excluded because of platform limitations in the CI. 
* A scenario that is not systematically run is no longer relevant.

# Review the formatting of the following on the dashboard

It looks cramped together.

Priority Breakdown:
Highest 6, High 35, Medium 68, Low 31, Lowest 10

# Facets

Why not including an issue type breakdown and systematically put information about the facets instead of just including the priority breakdown?.

# Fix warnings

As of 2026-05-08, running `./bin/predictability-engine batch data/samples/sample_data_large.csv` emits this
warning ~20 times per format that invokes JSON rendering:

```
/home/cbroult/.rvm/gems/ruby-4.0.3/gems/json-2.19.4/lib/json/common.rb:958: warning: JSON.generate: UTF-8 string passed as BINARY, this will raise an encoding error in json 3.0
```

The console output also only shows the last report path per format (e.g. `Task.html`, `Task.pdf`), not all 10.

1. Fix the UTF-8 / BINARY encoding warning in JSON generation.
2. Correct logging so all generated report paths appear, not just the last Task.xxx. Consider terse console output + richer file log.

# Remove obsolete README sections

* Playwright Setup seems obsolete

# Packwerk

Please look into implementing Packwerk so we enfore better modularity if that makes sense here.

# Performance of batch

Please analyze the innerworkings of the batch mode. I suspect that it could be faster (e.g., look at generating all formats at once like bug.md, .pdf, .pptx, etc). Please provide pros and cons and a recommended solution.

# Fix windows version

* The gem should not force the documentation installation (or maybe it is my local setup)
* PE setup fails
```powershell
PS C:\Users\cbrou> predictability-engine.bat setup
==> Installing Ruby dependencies

Bundler version 4.0.6 (2026-05-17 commit unknown)

Bundler commands:

  Primary commands:
    bundle install [OPTIONS]    # Install the current environment to the system
    bundle update [OPTIONS]     # Update the current environment
    bundle cache [OPTIONS]      # Locks and then caches all of the gems into ...
    bundle exec [OPTIONS]       # Run the command in context of the bundle
    bundle config NAME [VALUE]  # Retrieve or set a configuration value
    bundle help [COMMAND]       # Describe available commands or one specific...

  Utilities:
    bundle add GEM VERSION         # Add gem to Gemfile and run bundle install
    bundle binstubs GEM [OPTIONS]  # Install the binstubs of the listed gem
    bundle check [OPTIONS]         # Checks if the dependencies listed in Gem...
    bundle clean [OPTIONS]         # Cleans up unused gems in your bundler directory
    bundle console [GROUP]         # Opens an IRB session with the bundle pre-loaded
    bundle doctor [OPTIONS]        # Checks the bundle for common problems
    bundle env                     # Print information about the environment ...
    bundle fund [OPTIONS]          # Lists information about gems seeking fun...
    bundle gem NAME [OPTIONS]      # Creates a skeleton for creating a rubygem
    bundle info GEM [OPTIONS]      # Show information for the given gem
    bundle init [OPTIONS]          # Generates a Gemfile into the current wor...
    bundle issue                   # Learn how to report an issue in Bundler
    bundle licenses                # Prints the license of all gems in the bundle
    bundle list                    # List all gems in the bundle
    bundle lock                    # Creates a lockfile without installing
    bundle open GEM                # Opens the source directory of the given ...
    bundle outdated GEM [OPTIONS]  # List installed gems with newer versions ...
    bundle platform [OPTIONS]      # Displays platform compatibility information
    bundle plugin                  # Manage the bundler plugins
    bundle pristine [GEMS...]      # Restores installed gems to pristine condition
    bundle remove [GEM [GEM ...]]  # Removes gems from the Gemfile
    bundle show GEM [OPTIONS]      # Shows all gems that are part of the bund...
    bundle version                 # Prints Bundler version information

Options:
      [--no-color]                                   # Disable colorization in output
  -r, [--retry=NUM]                                  # Specify the number of times you wish to attempt network commands
  -V, [--verbose], [--no-verbose], [--skip-verbose]  # Enable verbose output mode

Could not locate Gemfile
C:/Users/cbrou/.local/share/gem/ruby/4.0.0/gems/predictability-engine-0.6.6/lib/predictability_engine/setup_manager.rb:27:in 'block in PredictabilityEngine::SetupManager#install_ruby_dependencies': bundle install failed (PredictabilityEngine::Error)
        from C:/ProgramData/rvm/envs/ruby-4.0.3/lib/ruby/4.0.0/bundler.rb:397:in 'block in Bundler.with_unbundled_env'
        from C:/ProgramData/rvm/envs/ruby-4.0.3/lib/ruby/4.0.0/bundler.rb:676:in 'Bundler.with_env'
        from C:/ProgramData/rvm/envs/ruby-4.0.3/lib/ruby/4.0.0/bundler.rb:397:in 'Bundler.with_unbundled_env'
        from C:/Users/cbrou/.local/share/gem/ruby/4.0.0/gems/predictability-engine-0.6.6/lib/predictability_engine/setup_manager.rb:26:in 'PredictabilityEngine::SetupManager#install_ruby_dependencies'
        from C:/Users/cbrou/.local/share/gem/ruby/4.0.0/gems/predictability-engine-0.6.6/lib/predictability_engine/setup_manager.rb:12:in 'PredictabilityEngine::SetupManager#run'
        from C:/Users/cbrou/.local/share/gem/ruby/4.0.0/gems/predictability-engine-0.6.6/lib/predictability_engine/cli.rb:226:in 'PredictabilityEngine::Cli#setup'
        from C:/Users/cbrou/.local/share/gem/ruby/4.0.0/gems/thor-1.5.0/lib/thor/command.rb:28:in 'Thor::Command#run'
        from C:/Users/cbrou/.local/share/gem/ruby/4.0.0/gems/thor-1.5.0/lib/thor/invocation.rb:127:in 'Thor::Invocation#invoke_command'
        from C:/Users/cbrou/.local/share/gem/ruby/4.0.0/gems/thor-1.5.0/lib/thor.rb:538:in 'Thor.dispatch'
        from C:/Users/cbrou/.local/share/gem/ruby/4.0.0/gems/thor-1.5.0/lib/thor/base.rb:585:in 'Thor::Base::ClassMethods#start'
        from C:/Users/cbrou/.local/share/gem/ruby/4.0.0/gems/predictability-engine-0.6.6/bin/predictability-engine:19:in '<top (required)>'
        from C:/ProgramData/rvm/envs/ruby-4.0.3/lib/ruby/4.0.0/rubygems.rb:304:in 'Kernel#load'
        from C:/ProgramData/rvm/envs/ruby-4.0.3/lib/ruby/4.0.0/rubygems.rb:304:in 'Gem.activate_and_load_bin_path'
        from C:/ProgramData/rvm/envs/ruby-4.0.3/bin/predictability-engine:36:in '<main>'
PS C:\Users\cbrou>




```