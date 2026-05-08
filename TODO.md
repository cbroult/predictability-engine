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

# Dead program tell no lies

Please review the of the following pattern in the code:
```ruby
      rescue StandardError
        {}
      end
```

For example, I see a high risk of ignoring errors in configuration files and then having the user confused when the configuration is not working due to a syntax error.

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

# Clean up

* Please remove things that have been done from this file.
