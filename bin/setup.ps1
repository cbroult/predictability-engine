#Requires -Version 5.1
<#
.SYNOPSIS
  Bootstrap Ruby and the Predictability Engine on Windows.
.DESCRIPTION
  Installs Ruby 4.x + MSYS2 DevKit via winget (if Ruby >= 4 is not already present),
  then runs gem install bundler, bundle install, and predictability-engine setup
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

function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $user    = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    $env:PATH = "$machine;$user"
}

function Install-Ruby {
    $rubyVersion = (Get-Content .ruby-version).Trim() -replace '^ruby-', ''

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "==> Installing Ruby+Devkit 4.x via winget..."
        winget install --id RubyInstallerTeam.RubyWithDevKit.4 --source winget --silent --accept-package-agreements --accept-source-agreements
        Refresh-Path
    } else {
        Write-Host @"

ERROR: winget not found. Install Ruby $rubyVersion manually:

  Option 1 (Recommended):
    Download Ruby+Devkit $rubyVersion-x64 from https://rubyinstaller.org/downloads/
    Run the installer and check "Add Ruby to PATH".

  Option 2:
    Install winget (App Installer) from the Microsoft Store, then re-run:
      bin\setup.bat

After installing Ruby, re-run: bin\setup.bat
"@
        exit 1
    }
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

# Verify Ruby is reachable after install (winget may require a new terminal on first install)
$major = Get-RubyMajorVersion
if ($null -eq $major -or $major -lt $RequiredRubyMajor) {
    Write-Host @"

ERROR: Ruby is not in PATH after installation.
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
