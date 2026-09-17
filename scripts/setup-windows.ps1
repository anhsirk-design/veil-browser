<#
.SYNOPSIS
    Check the Windows prerequisites for building Veil (Chromium + brave-core).

.DESCRIPTION
    This script CHECKS and REPORTS. It installs nothing and changes nothing on
    your machine. Every requirement it verifies comes from upstream's Windows
    build documentation plus brave-core's own hard `devEngines` constraints.

    Read docs/development-workflow.md for the full picture.

.PARAMETER Workspace
    The build workspace path that will hold src/, src/brave/, vendor/ and out/.
    Defaults to $env:VEIL_WORKSPACE, then to C:\veil-build.

.EXAMPLE
    .\scripts\setup-windows.ps1
    .\scripts\setup-windows.ps1 -Workspace C:\veil-build
#>

[CmdletBinding()]
param(
    [string]$Workspace = $(if ($env:VEIL_WORKSPACE) { $env:VEIL_WORKSPACE } else { 'C:\veil-build' })
)

$ErrorActionPreference = 'Continue'

# brave-core's devEngines constraints (onFail: "error" -> hard failures).
$MinNode = [version]'24.16.0'
$MaxNode = [version]'25.0.0'
$MinPnpm = [version]'11.11.0'
$MinGit  = [version]'2.41.0'

$script:Failures = 0
$script:Warnings = 0

function Write-Head([string]$Text) {
    Write-Host ''
    Write-Host "== $Text ==" -ForegroundColor Cyan
}

function Pass([string]$Text)  { Write-Host "  [ ok ] $Text" -ForegroundColor Green }
function Warn([string]$Text)  { Write-Host "  [warn] $Text" -ForegroundColor Yellow; $script:Warnings++ }
function Fail([string]$Text)  { Write-Host "  [FAIL] $Text" -ForegroundColor Red;    $script:Failures++ }
function Info([string]$Text)  { Write-Host "         $Text" -ForegroundColor DarkGray }

function Get-CommandVersion([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }
    try {
        $raw = & $Name --version 2>$null
        if (-not $raw) { return $null }
        $m = [regex]::Match(($raw | Out-String), '(\d+)\.(\d+)\.(\d+)')
        if ($m.Success) { return [version]$m.Value }
        $m2 = [regex]::Match(($raw | Out-String), '(\d+)\.(\d+)')
        if ($m2.Success) { return [version]$m2.Value }
        return $null
    } catch { return $null }
}

Write-Host ''
Write-Host 'Veil - Windows prerequisite check' -ForegroundColor White
Write-Host 'Nothing is installed or modified by this script.' -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
Write-Head 'Workspace path'

if ($Workspace -match '\s') {
    Fail "Workspace path contains a space: $Workspace"
    Info 'Chromium build tools break on paths containing spaces.'
    Info 'Use e.g. C:\veil-build'
} else {
    Pass "No spaces in workspace path: $Workspace"
}

if ($Workspace -match '^[A-Za-z]:\\[^\\]+$' -or $Workspace -match '^/') {
    Pass 'Workspace is at the root of a drive (required).'
} else {
    Warn "Workspace is not at a drive root: $Workspace"
    Info 'Strongly recommended: build at the root of a drive (e.g. C:\veil-build).'
    Info 'Paths >256 chars break the build, and a folder-mounted drive will not work at all.'
}

if ($Workspace.Length -gt 40) {
    Warn "Workspace path is quite long ($($Workspace.Length) chars). Total path length matters, not just this part."
}

$parent = Split-Path -Parent $Workspace
if ($parent -and -not (Test-Path $parent)) {
    Warn "Parent directory does not exist yet: $parent"
} else {
    Pass "Parent directory exists: $parent"
}

# ---------------------------------------------------------------------------
Write-Head 'Disk space'

$driveLetter = if ($Workspace -match '^([A-Za-z]):') { $Matches[1] } else { $null }
if ($driveLetter) {
    $di = [System.IO.DriveInfo]::new("${driveLetter}:\")
    if ($di.IsReady) {
        $freeGb = [math]::Round($di.AvailableFreeSpace / 1GB, 1)
        if ($freeGb -ge 150) {
            Pass "$($di.Name) has $freeGb GB free."
        } elseif ($freeGb -ge 80) {
            Warn "$($di.Name) has only $freeGb GB free."
            Info 'A Chromium checkout is ~60 GB. Build output needs substantially more.'
            Info '150+ GB free is recommended.'
        } else {
            Fail "$($di.Name) has only $freeGb GB free - not enough for a Chromium build."
        }
    } else {
        Warn "Drive ${driveLetter}: is not ready."
    }
} else {
    Warn 'Could not determine the drive for the workspace; check disk space manually.'
}

# ---------------------------------------------------------------------------
Write-Head 'Memory'

$ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
if ($ramGb -ge 32) {
    Pass "$ramGb GB RAM."
} elseif ($ramGb -ge 16) {
    Warn "$ramGb GB RAM - workable but tight for Chromium linking."
    Info 'More RAM is strongly preferred; expect long link steps and possible swapping.'
} else {
    Fail "$ramGb GB RAM - below what a Chromium build realistically needs."
}

# ---------------------------------------------------------------------------
Write-Head 'Git'

$gitVer = Get-CommandVersion 'git'
if ($gitVer) {
    if ($gitVer -ge $MinGit) {
        Pass "git $gitVer"
    } else {
        Fail "git $gitVer is older than the required $MinGit. Update from https://git-scm.com"
    }
} else {
    Fail 'git not found. Install Git 2.41+ from https://git-scm.com'
}
Info 'Do NOT use the Git bundled inside depot_tools - it is incompatible with Brave''s patch tooling.'

$gitName  = (git config --global user.name  2>$null)
$gitEmail = (git config --global user.email 2>$null)
if ($gitName -and $gitEmail) {
    Pass "git identity configured: $gitName <$gitEmail>"
} else {
    Warn 'git user.name / user.email are not both set globally.'
}

# ---------------------------------------------------------------------------
Write-Head 'Node.js and pnpm'

$nodeVer = Get-CommandVersion 'node'
if ($nodeVer) {
    if ($nodeVer -ge $MinNode -and $nodeVer -lt $MaxNode) {
        Pass "node $nodeVer"
    } else {
        Fail "node $nodeVer does not satisfy brave-core's hard requirement: >=$MinNode <$MaxNode"
        Info 'brave-core declares this in devEngines with onFail:"error" - install/upgrade Node 24.x.'
    }
} else {
    Fail 'node not found. Install Node.js v24+ from https://nodejs.org'
}

$pnpmVer = Get-CommandVersion 'pnpm'
if ($pnpmVer) {
    if ($pnpmVer -ge $MinPnpm) {
        Pass "pnpm $pnpmVer"
    } else {
        Fail "pnpm $pnpmVer is older than the required $MinPnpm."
        Info 'Run: npm install -g pnpm@latest'
    }
} else {
    Fail 'pnpm not found. brave-core requires pnpm >=11.11.0 and fails hard without it.'
    Info 'Run: npm install -g pnpm@latest'
}

# ---------------------------------------------------------------------------
Write-Head 'Python'

$pyVersion = $null
foreach ($candidate in @('python', 'py')) {
    try {
        $raw = & $candidate --version 2>$null
        if ($raw -match '(\d+\.\d+\.\d+)') { $pyVersion = $Matches[1]; break }
    } catch { }
}
if ($pyVersion) {
    Pass "python $pyVersion"
    Info 'The build uses depot_tools'' own Python. Do not put it on your PATH.'
} else {
    Warn 'No Python 3 found on PATH. Chromium expects Python 3 available.'
}

# ---------------------------------------------------------------------------
Write-Head 'Visual Studio C++ toolchain'

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path $vswhere) {
    $vsInstall = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ($vsInstall) {
        $vsVersion = & $vswhere -latest -products * -property installationVersion 2>$null
        Pass "Visual Studio with C++ tools found: $vsInstall"
        Info "Version: $vsVersion"
        Info 'Upstream specifies 2022 Update 17.8.3 or later.'
    } else {
        Fail 'Visual Studio installed but without the Desktop development with C++ workload.'
        Info 'Install the workload plus the Windows SDK.'
    }
} else {
    Fail 'vswhere not found - Visual Studio does not appear to be installed.'
    Info 'Install Visual Studio Community 2022 (17.8.3+) with Desktop development with C++.'
    Info 'See docs/development-workflow.md section 1.'
}

# ---------------------------------------------------------------------------
Write-Head 'Windows Developer Mode'

$devMode = $null
try {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    if (Test-Path $key) {
        $devMode = (Get-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
    }
} catch { }
if ($devMode -eq 1) {
    Pass 'Developer Mode is enabled.'
} else {
    Warn 'Developer Mode does not appear to be enabled.'
    Info 'Settings > System > For developers > Developer Mode.'
}

# ---------------------------------------------------------------------------
Write-Head 'depot_tools and build tooling'

foreach ($tool in @('gclient', 'gn', 'autoninja', 'ninja', 'vpython3')) {
    $found = Get-Command $tool -ErrorAction SilentlyContinue
    if ($found) {
        Pass "$tool present"
    } else {
        Info "$tool not on PATH (expected - brave-core bootstraps it during 'pnpm run init')"
    }
}

# ---------------------------------------------------------------------------
Write-Head 'Workspace state'

if (Test-Path $Workspace) {
    $braveCore = Join-Path $Workspace 'src\brave'
    $chromium  = Join-Path $Workspace 'src\chrome'
    if (Test-Path $braveCore) { Pass "brave-core present at $braveCore" } else { Info "brave-core not fetched yet: $braveCore" }
    if (Test-Path $chromium)  { Pass 'Chromium appears to be checked out' }     else { Info 'Chromium not fetched yet (done by pnpm run init)' }
} else {
    Info "Workspace does not exist yet: $Workspace"
    Info 'Run scripts/fetch-upstream.ps1 to create it.'
}

# ---------------------------------------------------------------------------
Write-Head 'Summary'

Write-Host ''
if ($script:Failures -eq 0 -and $script:Warnings -eq 0) {
    Write-Host 'All checks passed.' -ForegroundColor Green
} elseif ($script:Failures -eq 0) {
    Write-Host "$($script:Warnings) warning(s), no blocking failures." -ForegroundColor Yellow
} else {
    Write-Host "$($script:Failures) blocking failure(s), $($script:Warnings) warning(s)." -ForegroundColor Red
    Write-Host ''
    Write-Host 'Resolve the failures above before attempting a build.' -ForegroundColor Red
}
Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Cyan
Write-Host "  1. .\scripts\verify-pins.ps1"
Write-Host "  2. `$env:VEIL_WORKSPACE = '$Workspace'"
Write-Host '  3. .\scripts\fetch-upstream.ps1'
Write-Host '  4. .\scripts\build.ps1'
Write-Host ''

if ($script:Failures -gt 0) { exit 1 } else { exit 0 }
