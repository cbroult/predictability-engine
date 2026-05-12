# deploy-windows-agent.ps1 - install Woodpecker exec agent on this Windows machine
#
# Scenario: Woodpecker exec agent running on a Windows host for Windows gem testing
#   Given  This script runs as Administrator on a Windows host on the cbp-org LAN
#          CBP-Org Root CA trusted (Cert:\LocalMachine\Root)
#          192.168.16.23 (nexus) reachable on the LAN
#          WOODPECKER_AGENT_SECRET env var set (or passed as -AgentSecret)
#          Internet access to download woodpecker-agent binary from GitHub releases
#   When   this script runs
#   Then   cbp-org.internal hostnames added to hosts file (ensures DNS resolves even
#          when the router's IPv6 DNS takes precedence over the LAN DNS server)
#          C:\cbp-org.internal\woodpecker-agent\ directory exists with agent binary + config
#          CBP-Org root CA exported to C:\cbp-org.internal\woodpecker-agent\cbp-org-root-ca.pem
#          SSL_CERT_FILE set in agent environment (ensures Ruby OpenSSL trusts CBP-Org CA)
#          WoodpeckerAgent scheduled task registered as SYSTEM and running
#          Agent connects to ci.cbp-org.internal and appears in /api/agents
#          (Optional) admin SSH public key written to administrators_authorized_keys
#
# Idempotent: safe to re-run; stops existing agent before updating, restarts after.
#
# Usage (elevated PowerShell on the host, or via SSH from workstation):
#   powershell -ExecutionPolicy Bypass -File deploy-windows-agent.ps1 `
#     -AgentSecret "$(ssh root@nexus.cbp-org.internal -p 32523 grep WOODPECKER_AGENT_SECRET /volume1/docker/woodpecker/.env | cut -d= -f2)"
#
# For a second Windows agent, pass -AgentHostname to override the default ($env:COMPUTERNAME).
# Optionally pass -AdminSshPubKey to enable passwordless admin SSH from the workstation:
#   -AdminSshPubKey (Get-Content ~/.ssh/id_ed25519.pub)
#
# Agent binary version must match the Woodpecker server version exactly.
# Server version: check Woodpecker UI → Settings → Agents.
#
# Required elevation: Administrator (to modify hosts file, install scheduled task, set ACLs)

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$AgentSecret = $env:WOODPECKER_AGENT_SECRET,

    [string]$AgentDir       = "C:\cbp-org.internal\woodpecker-agent",
    [string]$ServerHost     = "nexus.cbp-org.internal",
    [int]$GrpcPort          = 9000,
    [int]$MaxWorkflows      = 2,
    [string]$AgentVersion   = "v3.14.0",  # must match server version exactly
    # Hostname reported to Woodpecker CI - defaults to the machine's own name.
    # Override with -AgentHostname when deploying a second Windows agent.
    [string]$AgentHostname  = $env:COMPUTERNAME,
    # Optional: path to the LAN IP of nexus for hosts-file injection.
    [string]$NexusIp        = "192.168.16.23",
    # Optional: SSH public key string to append to administrators_authorized_keys,
    # enabling passwordless admin SSH from the workstation without UAC workarounds.
    # Example: -AdminSshPubKey (Get-Content ~/.ssh/id_cbp_admin.pub)
    [string]$AdminSshPubKey = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Pass = 0; $Fail = 0
function Ok   { param($msg) Write-Host "  [PASS] $msg"; $script:Pass++ }
function Fail { param($msg) Write-Host "  [FAIL] $msg"; $script:Fail++ }
function Info { param($msg) Write-Host "  [INFO] $msg" }
function Summary {
    Write-Host ""
    $total = $script:Pass + $script:Fail
    if ($script:Fail -eq 0) {
        Write-Host "  RESULT: PASS - $($script:Pass)/$total checks passed"
    } else {
        Write-Host "  RESULT: FAIL - $($script:Pass)/$total passed, $($script:Fail) failed"
    }
}

Write-Host "══════════════════════════════════════════════════════════════════════════"
Write-Host "  Woodpecker Windows Agent Deploy - $env:COMPUTERNAME"
Write-Host "  Server: ${ServerHost}:${GrpcPort}   Version: ${AgentVersion}"
Write-Host "══════════════════════════════════════════════════════════════════════════"
Write-Host ""

# ── Preflight ─────────────────────────────────────────────────────────────────
if (-not $AgentSecret) {
    Write-Error "WOODPECKER_AGENT_SECRET must be set or passed as -AgentSecret."
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must run as Administrator (required for Windows service install)."
}
Info "Running as Administrator"

# ── Step 1: Ensure cbp-org.internal DNS resolution ───────────────────────────
# On Windows, the router's IPv6 DNS (fritz.box) can take precedence over the LAN
# DNS server configured on the Ethernet interface, making cbp-org.internal names
# unresolvable. Injecting them into the hosts file guarantees resolution regardless
# of adapter priority or IPv6 router advertisements.
Write-Host ""
Write-Host "==> Ensuring cbp-org.internal hosts file entries..."
$hostsFile = 'C:\Windows\System32\drivers\etc\hosts'
$cbpHosts  = @(
    "nexus.cbp-org.internal",
    "ci.cbp-org.internal",
    "gems.cbp-org.internal",
    "git.cbp-org.internal"
)
$hostsContent = Get-Content $hostsFile -Raw
foreach ($h in $cbpHosts) {
    if ($hostsContent -match [regex]::Escape($h)) {
        Info "Already present: $h"
    } else {
        Add-Content -Path $hostsFile -Value "$NexusIp  $h"
        Info "Added: $NexusIp  $h"
    }
}

# ── Step 1b: Optional admin SSH key setup ─────────────────────────────────────
# Writing a public key to administrators_authorized_keys enables passwordless admin
# SSH from the workstation, eliminating UAC-via-VBScript workarounds for future
# deployments and maintenance.
if ($AdminSshPubKey) {
    Write-Host ""
    Write-Host "==> Setting up admin SSH access..."
    $adminKeysFile = 'C:\ProgramData\ssh\administrators_authorized_keys'
    $existing = if (Test-Path $adminKeysFile) { Get-Content $adminKeysFile -Raw } else { "" }
    if ($existing -match [regex]::Escape($AdminSshPubKey.Trim())) {
        Info "SSH public key already in administrators_authorized_keys"
    } else {
        Add-Content -Path $adminKeysFile -Value $AdminSshPubKey.Trim()
        # OpenSSH on Windows requires strict ACL on administrators_authorized_keys:
        # only SYSTEM and Administrators may have access.
        icacls $adminKeysFile /inheritance:r | Out-Null
        icacls $adminKeysFile /grant "NT AUTHORITY\SYSTEM:(F)" | Out-Null
        icacls $adminKeysFile /grant "BUILTIN\Administrators:(F)" | Out-Null
        Info "SSH public key added; ACL locked to SYSTEM + Administrators"
    }
}

# ── Step 2: Ensure PowerShell 7 (pwsh) is installed ──────────────────────────
# CI scripts are run with pwsh so they use UTF-8 by default (PS 5.x uses the
# system code page, which can corrupt non-ASCII characters in string literals).
Write-Host ""
Write-Host "==> Ensuring PowerShell 7 (pwsh) is installed..."
$pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwshCmd) {
    $pwshVer = & pwsh --version
    Info "Already installed: $pwshVer"
} else {
    choco install -y powershell-core --no-progress
    Info "Installed PowerShell 7 via Chocolatey"
}

# ── Step 3: Ensure Ruby 4.0.3 (rvm-windows) is installed and in Machine PATH ──
# Ruby must be in the Machine PATH so the SYSTEM account (which runs the agent
# and therefore all CI steps) can invoke ruby/gem/predictability-engine.
# User-level PATH entries are invisible to SYSTEM.
# rvm-windows stores each Ruby version under C:\ProgramData\rvm\envs\ruby-X.Y.Z\
# which is machine-wide, so SYSTEM can read binaries directly from there.
# The rvm wrapper scripts (C:\ProgramData\rvm\wrapper\ruby.bat) resolve via
# Node.js scripts in cbrou's user profile and therefore cannot be used by SYSTEM.
$RubyVersion    = "ruby-4.0.3"
$RvmEnvBin      = "C:\ProgramData\rvm\envs\$RubyVersion\bin"
Write-Host ""
Write-Host "==> Ensuring $RubyVersion is installed and in Machine PATH..."
if (Test-Path "$RvmEnvBin\ruby.exe") {
    Info "$RubyVersion already installed at $RvmEnvBin"
} else {
    Info "Installing $RubyVersion via rvm-windows..."
    cmd /c "rvm install $RubyVersion" 2>&1 | ForEach-Object { Info $_ }
    cmd /c "rvm use $RubyVersion --default" 2>&1 | ForEach-Object { Info $_ }
}
# Pin the rvm-managed bin dir directly in Machine PATH (bypasses the wrapper).
$machinePath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
# Remove any other Ruby bin entries to avoid version conflicts.
$machinePath = ($machinePath -split ';' | Where-Object { $_ -notmatch '\\rvm\\envs\\ruby-' -and $_ -notmatch '\\Ruby\d' }) -join ';'
$machinePath = "$machinePath;$RvmEnvBin"
[System.Environment]::SetEnvironmentVariable('PATH', $machinePath, 'Machine')
$env:PATH = $machinePath
Info "Machine PATH set to use $RvmEnvBin"
Info "Ruby: $(& "$RvmEnvBin\ruby.exe" --version)"

# ── Step 4: Create agent directory ────────────────────────────────────────────
Write-Host ""
Write-Host "==> Creating agent directory: $AgentDir"
if (-not (Test-Path $AgentDir)) {
    New-Item -ItemType Directory -Path $AgentDir -Force | Out-Null
    Info "Created $AgentDir"
} else {
    Info "$AgentDir already exists"
}

# ── Step 5: Download woodpecker-agent binary ──────────────────────────────────
$agentExe = "$AgentDir\woodpecker-agent.exe"
$downloadUrl = "https://github.com/woodpecker-ci/woodpecker/releases/download/${AgentVersion}/woodpecker-agent_windows_amd64.zip"
$zipPath    = "$AgentDir\woodpecker-agent_windows_amd64.zip"
$extractDir = "$AgentDir\extract-tmp"

Write-Host ""
Write-Host "==> Downloading woodpecker-agent ${AgentVersion}..."
# Stop existing task and process before replacing the binary
Stop-ScheduledTask -TaskName "WoodpeckerAgent" -ErrorAction SilentlyContinue
Get-Process -Name "woodpecker-agent" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

try {
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
    $size = (Get-Item $zipPath).Length
    Info "Downloaded woodpecker-agent_windows_amd64.zip (${size} bytes)"
    if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
    $exeSource = Get-ChildItem -Path $extractDir -Filter "woodpecker-agent.exe" -Recurse | Select-Object -First 1
    if (-not $exeSource) { Write-Error "woodpecker-agent.exe not found in zip" }
    Copy-Item $exeSource.FullName -Destination $agentExe -Force
    Remove-Item -Recurse -Force $extractDir
    Remove-Item -Force $zipPath
    Info "Extracted woodpecker-agent.exe to $agentExe"
} catch {
    Write-Error "Download/extract failed from $downloadUrl : $_"
}

# ── Step 6: Export CBP-Org root CA to PEM for Ruby SSL ────────────────────────
$caCertPath = "$AgentDir\cbp-org-root-ca.pem"
Write-Host ""
Write-Host "==> Exporting CBP-Org root CA to $caCertPath..."
$cert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -match "CBP-Org" } | Select-Object -First 1
if ($cert) {
    # Export DER bytes and convert to PEM
    $derBytes   = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    $b64        = [Convert]::ToBase64String($derBytes)
    # Wrap at 64 chars per PEM spec
    $wrapped    = ($b64 -split '(.{64})' | Where-Object { $_ }) -join "`n"
    $pem        = "-----BEGIN CERTIFICATE-----`n$wrapped`n-----END CERTIFICATE-----`n"
    [System.IO.File]::WriteAllText($caCertPath, $pem)
    Info "Exported CBP-Org CA to $caCertPath"
} else {
    Write-Error "CBP-Org root CA not found in Cert:\LocalMachine\Root - run setup-windows-firefox-trust.ps1 first."
}

# ── Step 7: Write agent configuration file ────────────────────────────────────
$envFile = "$AgentDir\agent.env"
Write-Host ""
Write-Host "==> Writing agent configuration to $envFile..."

# WOODPECKER_FILTER_LABELS ensures this agent ONLY accepts steps labeled platform=windows.
# Steps without that label continue to run on the Linux Docker agent on nexus.
$envContent = @"
WOODPECKER_SERVER=${ServerHost}:${GrpcPort}
WOODPECKER_AGENT_SECRET=${AgentSecret}
WOODPECKER_BACKEND=local
WOODPECKER_MAX_WORKFLOWS=${MaxWorkflows}
WOODPECKER_HOSTNAME=${AgentHostname}
WOODPECKER_FILTER_LABELS=platform=windows
WOODPECKER_LOG_LEVEL=info
WOODPECKER_AGENT_CONFIG_FILE=${AgentDir}\agent.conf
SSL_CERT_FILE=${caCertPath}
"@
[System.IO.File]::WriteAllText($envFile, $envContent)
Info "Configuration written (secret redacted from display)"
Info "  WOODPECKER_SERVER=${ServerHost}:${GrpcPort}"
Info "  WOODPECKER_BACKEND=local"
Info "  WOODPECKER_FILTER_LABELS=platform=windows"
Info "  WOODPECKER_AGENT_CONFIG_FILE=$AgentDir\agent.conf"
Info "  SSL_CERT_FILE=$caCertPath"

# ── Step 8: Create launcher wrapper script ────────────────────────────────────
# The woodpecker-agent binary is a plain Go console process - it does not implement
# the Windows Service Control Manager API, so sc.exe create fails with error 1053.
# A PowerShell wrapper launched by a Scheduled Task is the native alternative:
# the task reads agent.env, sets all env vars, then exec's the agent binary.
$launcherPath = "$AgentDir\agent-start.ps1"
Write-Host ""
Write-Host "==> Writing launcher script to $launcherPath..."
$launcherContent = @"
# agent-start.ps1 -- launched by WoodpeckerAgent scheduled task at startup
# Reads agent.env, sets env vars, then runs woodpecker-agent.exe.
Get-Content "$envFile" | ForEach-Object {
    if (`$_ -match '^([^#=\s][^=]*)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable(`$matches[1], `$matches[2], 'Process')
    }
}
& "$agentExe"
"@
[System.IO.File]::WriteAllText($launcherPath, $launcherContent)
Info "Launcher written to $launcherPath"

# ── Step 9: Lock down file permissions ───────────────────────────────────────
# By default C:\ propagates BUILTIN\Users:(RX) and Authenticated Users:(M) to all
# sub-directories. Both must be removed: Users can read WOODPECKER_AGENT_SECRET and
# Authenticated Users can replace woodpecker-agent.exe or inject code into agent-start.ps1.
Write-Host ""
Write-Host "==> Locking down permissions on $AgentDir..."
# Remove stale diagnostic files from debugging sessions
Get-ChildItem -Path $AgentDir -Filter "*.txt" -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $AgentDir -Filter "test-*.ps1" -ErrorAction SilentlyContinue | Remove-Item -Force
# Remove the old C:\woodpecker-agent path if it still exists from a previous deploy
if (Test-Path "C:\woodpecker-agent") { Remove-Item -Recurse -Force "C:\woodpecker-agent" }
# Break ACL inheritance (keep existing explicit ACEs, stop inheriting from C:\)
icacls $AgentDir /inheritance:d | Out-Null
# Remove broad groups from the entire subtree
icacls $AgentDir /remove "BUILTIN\Users" /T | Out-Null
icacls $AgentDir /remove "NT AUTHORITY\Authenticated Users" /T | Out-Null
# Re-grant SYSTEM and Administrators explicitly (they had inherited grants; now explicit)
icacls $AgentDir /grant:r "NT AUTHORITY\SYSTEM:(OI)(CI)(F)" | Out-Null
icacls $AgentDir /grant:r "BUILTIN\Administrators:(OI)(CI)(F)" | Out-Null
Info "Permissions locked: SYSTEM + Administrators only (WOODPECKER_AGENT_SECRET protected)"

# ── Step 10: Register / update Scheduled Task ────────────────────────────────
Write-Host ""
Write-Host "==> Registering WoodpeckerAgent scheduled task..."

$taskName = "WoodpeckerAgent"
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Info "Removed existing scheduled task"
}

$action    = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File `"$launcherPath`""
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 10 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Woodpecker CI exec-backend agent (platform=windows)" `
    -Force | Out-Null
Info "Scheduled task registered (runs at startup as SYSTEM)"

# ── Step 11: Start the task immediately ──────────────────────────────────────
Write-Host ""
Write-Host "==> Starting WoodpeckerAgent task..."
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 5

# ── THEN: post-conditions ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "── Post-conditions ───────────────────────────────────────────────────────"

# 1. cbp-org.internal DNS resolves
try {
    $addrs = [System.Net.Dns]::GetHostAddresses($ServerHost)
    Ok "DNS: $ServerHost resolves to $($addrs[0].IPAddressToString)"
} catch {
    Fail "DNS: $ServerHost does not resolve - hosts file entry may be missing"
}

# 2. Binary exists and is non-zero
if ((Test-Path $agentExe) -and (Get-Item $agentExe).Length -gt 0) {
    Ok "woodpecker-agent.exe present ($agentExe)"
} else {
    Fail "woodpecker-agent.exe missing or empty"
}

# 3. CA cert exported
if ((Test-Path $caCertPath) -and (Get-Content $caCertPath -Raw) -match "BEGIN CERTIFICATE") {
    Ok "CBP-Org CA exported to $caCertPath"
} else {
    Fail "CBP-Org CA PEM missing at $caCertPath"
}

# 4. Config file exists
if (Test-Path $envFile) {
    Ok "agent.env configuration present"
} else {
    Fail "agent.env missing at $envFile"
}

# 5. Scheduled task registered and running
$task = Get-ScheduledTask -TaskName "WoodpeckerAgent" -ErrorAction SilentlyContinue
if ($task -and $task.State -ne 'Unknown') {
    Ok "WoodpeckerAgent scheduled task registered (state: $($task.State))"
    $info = Get-ScheduledTaskInfo -TaskName "WoodpeckerAgent" -ErrorAction SilentlyContinue
    $proc = Get-Process -Name "woodpecker-agent" -ErrorAction SilentlyContinue
    if ($proc) {
        Ok "woodpecker-agent.exe process is running (PID $($proc.Id))"
    } else {
        Fail "woodpecker-agent.exe process not found (task registered but agent not yet running?)"
    }
} else {
    Fail "WoodpeckerAgent scheduled task not registered"
}

# 6. Port 9000 reachable from this machine
$conn = Test-NetConnection -ComputerName $ServerHost -Port $GrpcPort -WarningAction SilentlyContinue
if ($conn.TcpTestSucceeded) {
    Ok "TCP ${ServerHost}:${GrpcPort} reachable (gRPC)"
} else {
    Fail "TCP ${ServerHost}:${GrpcPort} NOT reachable - check firewall / Docker port mapping"
}

# 7. ACLs: no broad read access (WOODPECKER_AGENT_SECRET must not be world-readable)
$aclString = (Get-Acl $AgentDir).AccessToString
if ($aclString -notmatch "BUILTIN\\Users" -and $aclString -notmatch "Authenticated Users") {
    Ok "agent directory locked to SYSTEM + Administrators (secret not world-readable)"
} else {
    Fail "Broad group still in ACL - WOODPECKER_AGENT_SECRET may be readable by all users"
}

Summary
Write-Host ""
if ($script:Fail -eq 0) {
    Write-Host "══════════════════════════════════════════════════════════════════════════"
    Write-Host "  WoodpeckerAgent deployed. Check Woodpecker UI → Settings → Agents"
    Write-Host "  to confirm '$AgentHostname' appears as a connected agent."
    Write-Host "══════════════════════════════════════════════════════════════════════════"
} else {
    Write-Host "  Some checks failed. Review output above." -ForegroundColor Red
    exit 1
}
