#!/usr/bin/env sh
# build-rc-gem.sh — build a release-candidate gem (X.Y.Z.rc1) from the current version.
#
# Temporarily patches version.rb to X.Y.Z.rc1, builds the gem, then restores
# version.rb to X.Y.Z. The .rc1 gem is published to gems.cbp-org.internal for
# cross-platform validation before final promotion.
#
# No arguments. Reads current version from lib/predictability_engine/version.rb.

set -e

VERSION=$(ruby -e "load 'lib/predictability_engine/version.rb'; puts PredictabilityEngine::VERSION")
RC_VERSION="${VERSION}.rc1"

echo "build-rc-gem: building ${RC_VERSION}"

ruby -i -pe "gsub(\"VERSION = \\\"${VERSION}\\\"\", \"VERSION = \\\"${RC_VERSION}\\\"\")" \
  lib/predictability_engine/version.rb

gem build predictability-engine.gemspec

ruby -i -pe "gsub(\"VERSION = \\\"${RC_VERSION}\\\"\", \"VERSION = \\\"${VERSION}\\\"\")" \
  lib/predictability_engine/version.rb

echo "build-rc-gem: done — predictability-engine-${RC_VERSION}.gem"
