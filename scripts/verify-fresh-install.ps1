# verify-fresh-install.ps1 - Windows equivalent of verify-fresh-install.sh.
#
# Run by .woodpecker/publish.yml (verify-fresh-install-windows step) after
# `gem install predictability-engine` against gems.cbp-org.internal.
# Confirms that an end user on Windows can run all CLI subcommands and that
# every expected artefact lands on disk non-empty.
#
# Preconditions (set by the CI step):
#   - predictability-engine is installed
#   - node + playwright chromium are available
#   - cbp-org root CA is trusted

$ErrorActionPreference = 'Stop'

$WORK = 'C:\Temp\verify-fresh-install'
if (Test-Path $WORK) { Remove-Item -Recurse -Force $WORK }
New-Item -ItemType Directory -Path $WORK | Out-Null
Set-Location $WORK

# Locate shipped sample CSVs inside the installed gem.
$GEM_DATA = ruby -rpredictability_engine -e "puts File.dirname(PredictabilityEngine.sample_data_path)"
Write-Host "verify-fresh-install: using shipped samples from $GEM_DATA"

# Copy shipped samples into the workdir so report output lands in C:\Temp\...
Copy-Item "$GEM_DATA\sample_data.csv"       "$WORK\sample_data.csv"
Copy-Item "$GEM_DATA\sample_data_large.csv" "$WORK\sample_data_large.csv"
Copy-Item "$GEM_DATA\wip_data.csv"          "$WORK\wip_data.csv"

# Generate the XL stress dataset using the gem's own CLI.
predictability-engine generate --size=xl "$WORK\xl_data.csv"
if (-not (Test-Path "$WORK\xl_data.csv") -or (Get-Item "$WORK\xl_data.csv").Length -eq 0) {
  Write-Host 'FAIL: xl_data.csv not produced'
  exit 1
}

# Batch mode = all formats.
foreach ($csv in @('sample_data.csv', 'sample_data_large.csv', 'wip_data.csv', 'xl_data.csv')) {
  Write-Host "verify-fresh-install: batch $csv"
  predictability-engine batch "$WORK\$csv"
}

# Additional subcommands exercised on the small shipped sample.
predictability-engine summary  "$WORK\sample_data.csv"
predictability-engine forecast "$WORK\wip_data.csv" 10

# Assert every expected artefact exists and is non-empty.
$fail = 0
$artefacts = @(
  'dashboard.html', 'dashboard.md', 'dashboard.conf',
  'dashboard.pdf', 'dashboard.pptx', 'dashboard.png',
  'dashboard.csv', 'dashboard.xlsx'
)
foreach ($base in @('sample_data', 'sample_data_large', 'wip_data', 'xl_data')) {
  foreach ($artefact in $artefacts) {
    $path = "$WORK\reports\$base\$artefact"
    if (-not (Test-Path $path) -or (Get-Item $path).Length -eq 0) {
      Write-Host "FAIL: missing or empty artefact $path"
      $fail = 1
    }
  }
}

if ($fail -ne 0) {
  Write-Host 'verify-fresh-install: FAILED'
  exit 1
}

Write-Host 'verify-fresh-install: all artefacts generated successfully'
