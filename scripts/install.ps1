# install.ps1 - install predictability-engine globally from rubygems.org.
#
# Requires: Ruby >= 4.0.3. Node.js >= 18 is installed automatically
# via Chocolatey if not present (Chocolatey must be installed first).
#
# Usage:
#   pwsh -ExecutionPolicy Bypass -File scripts\install.ps1
$ErrorActionPreference = 'Stop'
gem install predictability-engine
predictability-engine setup
