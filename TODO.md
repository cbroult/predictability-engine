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

