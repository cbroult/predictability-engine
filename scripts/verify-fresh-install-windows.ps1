# verify-fresh-install-windows.ps1 — CI entrypoint for the Windows verify-fresh-install step.
#
# Run by .woodpecker/publish.yml (verify-fresh-install-windows step).
# Installs dependencies, installs the just-published gem from gems.cbp-org.internal,
# configures Playwright Chromium, then delegates to scripts\verify-fresh-install.ps1.
#
# Optional environment variables:
#   CBP_ORG_CA_CERT   — Base64-encoded cbp-org root CA certificate (only needed
#                       on machines where deploy-windows-agent.ps1 has not been run)
#
# Preconditions:
#   - Ruby is available (from the container image)
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

# Trust the cbp-org root CA so gem install and Playwright can reach internal hosts.
# On photocenter the CA is already trusted by deploy-windows-agent.ps1 (SSL_CERT_FILE set
# system-wide), so CBP_ORG_CA_CERT is optional — only needed for ad-hoc / Docker runs.
if ($env:CBP_ORG_CA_CERT) {
    $certBytes = [System.Convert]::FromBase64String($env:CBP_ORG_CA_CERT)
    [System.IO.File]::WriteAllBytes("$env:TEMP\cbp-org.cer", $certBytes)
    certutil -addstore -f Root "$env:TEMP\cbp-org.cer"
} else {
    Write-Host "CBP_ORG_CA_CERT not set — assuming CA already trusted on this host."
}

# Determine the gem version from the local version file (repo is cloned by CI).
$env:GEM_VERSION = (ruby -e "load 'lib/predictability_engine/version.rb'; puts PredictabilityEngine::VERSION")

# Install the freshly-published gem from the internal registry.
gem install predictability-engine --version $env:GEM_VERSION --source https://gems.cbp-org.internal --no-document

# Install Playwright and download the bundled Chromium browser.
# Use npm.cmd/npx.cmd — npm.ps1 is blocked by execution policy on unmanaged machines.
# PLAYWRIGHT_BROWSERS_PATH is a fixed shared location so the browser persists across CI runs
# and is the same path regardless of which Windows account runs the step (cbrou vs SYSTEM).
$env:PLAYWRIGHT_BROWSERS_PATH = 'C:\ProgramData\ms-playwright'
npm.cmd install playwright
npx.cmd playwright install chromium

# Run the platform-neutral verification script.
powershell -ExecutionPolicy Bypass -File scripts\verify-fresh-install.ps1
