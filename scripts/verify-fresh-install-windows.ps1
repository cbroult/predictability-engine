# verify-fresh-install-windows.ps1 - CI entrypoint for the Windows verify-fresh-install step.
#
# Run by .woodpecker/verify-windows.yml after the verify workflow passes.
# Installs the gem from rubygems.org (same source end users use), runs
# `predictability-engine setup`, then delegates to scripts\verify-fresh-install.ps1.
#
# Preconditions:
#   - Ruby is available (installed on the photocenter Windows agent)
#   - Chocolatey is available

$ErrorActionPreference = 'Stop'

# Install Node.js if not already available (Playwright installs its own Chromium separately).
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Host "Node.js already installed: $(node --version)"
} else {
    choco install -y nodejs --no-progress
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH','Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('PATH','User')
}

# Determine the gem version from the local version file (repo is cloned by CI).
$env:GEM_VERSION = (ruby -e "load 'lib/predictability_engine/version.rb'; puts PredictabilityEngine::VERSION")

# Install the freshly-published gem from rubygems.org (same source end users use).
gem install predictability-engine --version $env:GEM_VERSION --no-document

# Pin Chromium to a shared location so it persists across CI runs regardless of user account.
$env:PLAYWRIGHT_BROWSERS_PATH = 'C:\ProgramData\ms-playwright'

# One command installs Node modules (npm.cmd) and Playwright Chromium (npx.cmd) — the same
# flow an end user runs after `gem install predictability-engine`.
predictability-engine setup

# Run the platform-neutral verification script.
pwsh -ExecutionPolicy Bypass -File scripts\verify-fresh-install.ps1
