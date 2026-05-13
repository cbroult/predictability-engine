#!/usr/bin/env sh
# install.sh — install predictability-engine globally from rubygems.org.
#
# Requires: Ruby >= 4.0.3. Node.js >= 18 is installed automatically
# via the platform package manager (brew/apt-get/dnf) if not present.
#
# Usage:
#   sh scripts/install.sh
#   # or, after first install:
#   gem install predictability-engine && predictability-engine setup
set -eu
gem install predictability-engine
predictability-engine setup
