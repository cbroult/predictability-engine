#Requires -Version 5.1
<#
.SYNOPSIS
  Bootstrap Ruby and the Predictability Engine on Windows.
.DESCRIPTION
  Ensures Ruby 4.x + MSYS2 DevKit is installed (tries winget, Chocolatey, Scoop,
  then a direct SHA256-verified download from GitHub Releases), then runs
  gem install bundler, bundle install, and predictability-engine setup
  (which handles Node.js, Playwright, and Chromium).

  Invoke via the thin CMD wrapper:  bin\setup.bat
  Or directly from PowerShell:     powershell -ExecutionPolicy Bypass -File bin\setup.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RequiredRubyMajor = 4

# Change to repo root (one level above bin/)
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RepoRoot

function Get-RubyMajorVersion {
    try {
        $out = & ruby -e 'puts RUBY_VERSION.split(".").first' 2>$null
        $val = $out.Trim()
        if ($val -match '^\d+$') { return [int]$val }
    } catch { }
    return $null
}

function Test-RubyAdequate {
    $m = Get-RubyMajorVersion
    return ($null -ne $m) -and ($m -ge $RequiredRubyMajor)
}

function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $user    = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    $env:PATH = "$machine;$user"
}

function Install-RubyDirect {
    param([string]$RubyVersion)
    $tag     = "RubyInstaller-$RubyVersion-1"
    $exe     = "rubyinstaller-devkit-$RubyVersion-1-x64.exe"
    $baseUrl = "https://github.com/oneclick/rubyinstaller2/releases/download/$tag"
    $tmp     = Join-Path $env:TEMP $exe

    Write-Host "==> Downloading Ruby $RubyVersion installer from GitHub Releases..."
    Invoke-WebRequest -Uri "$baseUrl/$exe" -OutFile $tmp -UseBasicParsing

    Write-Host "==> Verifying SHA256 checksum..."
    $shaLines = (Invoke-WebRequest -Uri "$baseUrl/SHA256.txt" -UseBasicParsing).Content -split "`n"
    $expected = ($shaLines | Where-Object { $_ -match [regex]::Escape($exe) } |
                 ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1).ToUpper()
    $actual   = (Get-FileHash $tmp -Algorithm SHA256).Hash.ToUpper()
    if ($actual -ne $expected) {
        Remove-Item $tmp -Force
        throw "SHA256 mismatch for $exe`n  Expected: $expected`n  Got:      $actual"
    }

    Write-Host "==> Installing Ruby $RubyVersion (silent)..."
    Start-Process -FilePath $tmp -ArgumentList '/verysilent /tasks="assocfiles,modpath"' -Wait
    Remove-Item $tmp -Force
}

function Install-Ruby {
    $rubyVersion = (Get-Content .ruby-version).Trim() -replace '^ruby-', ''

    # Priority 1: winget (built into Windows 10 1809+ / Windows 11)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "==> Installing Ruby 4.x via winget..."
        winget install --id RubyInstallerTeam.RubyWithDevKit.4 --source winget --silent --accept-package-agreements --accept-source-agreements
        Refresh-Path
        if (Test-RubyAdequate) { return }
    }

    # Priority 2: Chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "==> Installing Ruby via Chocolatey..."
        & choco install ruby --yes
        Refresh-Path
        if (Test-RubyAdequate) { return }
    }

    # Priority 3: Scoop
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "==> Installing Ruby via Scoop..."
        & scoop install ruby
        Refresh-Path
        if (Test-RubyAdequate) { return }
    }

    # Priority 4: direct download from GitHub Releases with SHA256 verification
    Write-Host "==> No package manager found — downloading Ruby directly..."
    Install-RubyDirect -RubyVersion $rubyVersion
    Refresh-Path
}

# ── Main ───────────────────────────────────────────────────────────────────────
$major = Get-RubyMajorVersion
if ($null -eq $major) {
    Write-Host "==> Ruby not found."
    Install-Ruby
} elseif ($major -lt $RequiredRubyMajor) {
    Write-Host "==> Ruby $major.x found but Ruby >= $RequiredRubyMajor.0 is required."
    Install-Ruby
} else {
    Write-Host "==> Ruby $major.x found."
}

# Verify Ruby is reachable after install (PATH refresh may not propagate to parent shell)
if (-not (Test-RubyAdequate)) {
    Write-Host @"

ERROR: Ruby $RequiredRubyMajor+ is not in PATH after installation.
Close this terminal, open a new one, and re-run: bin\setup.bat
"@
    exit 1
}

Write-Host "==> Installing Bundler..."
& gem install bundler --conservative

Write-Host "==> Installing Ruby gems..."
& bundle install --jobs 4 --retry 3

Write-Host "==> Running Predictability Engine setup (Node.js, Playwright, Chromium)..."
& bundle exec predictability-engine setup
