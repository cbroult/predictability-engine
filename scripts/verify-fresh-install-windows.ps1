# verify-fresh-install-windows.ps1 - CI entrypoint for the Windows verify-fresh-install step.
#
# Run by .woodpecker/verify-windows.yml after the publish workflow succeeds.
# Downloads the X.Y.Z gem from Forgejo generic packages, installs it locally,
# runs `predictability-engine setup`, then delegates to scripts\verify-fresh-install.ps1.
#
# Preconditions:
#   - Ruby is available (installed on the photocenter Windows agent)
#   - Chocolatey is available
#   - CBP_ORG_CA_CERT env var holds the base64-encoded cbp-org root CA certificate
#   - FORGEJO_API_TOKEN env var holds a Forgejo API token with package read access

$ErrorActionPreference = 'Stop'

# Install Node.js if not already available (Playwright installs its own Chromium separately).
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Host "Node.js already installed: $(node --version)"
} else {
    choco install -y nodejs --no-progress
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH','Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('PATH','User')
}

# Trust the cbp-org root CA so git.cbp-org.internal SSL is accepted.
$certBytes = [System.Convert]::FromBase64String($env:CBP_ORG_CA_CERT)
[System.IO.File]::WriteAllBytes('C:\cbp-org.crt', $certBytes)
Import-Certificate -FilePath 'C:\cbp-org.crt' -CertStoreLocation Cert:\LocalMachine\Root

# Determine the version from the local version file (repo is cloned by CI).
$gemVersion = (ruby -e "load 'lib/predictability_engine/version.rb'; puts PredictabilityEngine::VERSION")
$gemFile = "predictability-engine-${gemVersion}.gem"

# Download gem artifact from Forgejo generic packages.
$forgejoUrl = "https://git.cbp-org.internal/api/packages/cbp-org/generic/predictability-engine/${gemVersion}/${gemFile}"
curl.exe -fsSL --cacert C:\cbp-org.crt `
    -H "Authorization: token $($env:FORGEJO_API_TOKEN)" `
    -o $gemFile `
    $forgejoUrl

# Install from local file (not from any gem registry).
gem install $gemFile --local --no-document

# Pin Chromium to a shared location so it persists across CI runs regardless of user account.
$env:PLAYWRIGHT_BROWSERS_PATH = 'C:\ProgramData\ms-playwright'

# One command installs Node modules (npm.cmd) and Playwright Chromium (npx.cmd).
predictability-engine setup

# Run the platform-neutral verification script.
pwsh -ExecutionPolicy Bypass -File scripts\verify-fresh-install.ps1
