<#
.SYNOPSIS
    Build Veil from the pinned upstream foundation.

.DESCRIPTION
    Wraps brave-core's two-stage build, executed inside <Workspace>\src\brave:

      1. pnpm run init   - downloads depot_tools, writes .gclient, runs
                           `gclient sync` (Chromium + ~240 repos, ~60 GB),
                           applies Brave's patches.
      2. pnpm run build  - GN configure + compile (hours; memory hungry).

    THIS IS THE EXPENSIVE STEP. Read docs/development-workflow.md section 1
    before running it. If your environment does not meet the prerequisites,
    stop now rather than three hours in.

.PARAMETER Workspace
    Build workspace. Defaults to $env:VEIL_WORKSPACE, then C:\veil-build.

.PARAMETER BuildType
    component (default) | Release | Static | Debug

.PARAMETER TargetOs
    windows (default) | linux | mac | ios | android

.PARAMETER TargetCpu
    x64 (default) | arm | arm64

.PARAMETER SkipInit
    Skip `pnpm run init`. Use when the source is already fetched and you only
    want to recompile.

.PARAMETER SkipDeps
    Skip the `pnpm install --frozen-lockfile` that upstream runs before its own
    scripts (only relevant if you manage node_modules yourself).

.EXAMPLE
    .\scripts\build.ps1
    .\scripts\build.ps1 -BuildType Release
    .\scripts\build.ps1 -SkipInit
#>

[CmdletBinding()]
param(
    [string]$Workspace = $(if ($env:VEIL_WORKSPACE) { $env:VEIL_WORKSPACE } else { 'C:\veil-build' }),
    [ValidateSet('component', 'Component', 'Release', 'Static', 'Debug')]
    [string]$BuildType = 'Component',
    [string]$TargetOs = 'windows',
    [string]$TargetCpu = 'x64',
    [switch]$SkipInit,
    [switch]$SkipDeps
)

$ErrorActionPreference = 'Stop'

$srcBrave = Join-Path $Workspace 'src\brave'

function Write-Step([string]$Text) { Write-Host "`n== $Text ==" -ForegroundColor Cyan }
function Write-Note([string]$Text) { Write-Host "   $Text" -ForegroundColor DarkGray }

function Invoke-InBraveCore([string]$Command) {
    Push-Location $srcBrave
    try {
        Write-Note "> $Command"
        & cmd.exe /c $Command
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE`: $Command"
        }
    } finally {
        Pop-Location
    }
}

Write-Host ''
Write-Host 'Veil - build' -ForegroundColor White

# --- Preconditions --------------------------------------------------------
Write-Step 'Checking workspace'

if (-not (Test-Path $srcBrave)) {
    throw "brave-core not found at $srcBrave. Run scripts/fetch-upstream.ps1 first."
}
if (-not (Test-Path (Join-Path $srcBrave 'package.json'))) {
    throw "$srcBrave does not look like brave-core (no package.json)."
}
if ($Workspace -match '\s') {
    throw "Workspace path contains a space. The Chromium build will fail. Use e.g. C:\veil-build"
}

$envFile = Join-Path $srcBrave '.env'
if (-not (Test-Path $envFile)) {
    Write-Warning "No .env found at $envFile"
    Write-Host '   A Veil build needs no Brave service credentials, but upstream expects the file.' -ForegroundColor DarkGray
    Write-Host '   Copy .env.example there first, or continue for a default developer build.' -ForegroundColor DarkGray
} else {
    Write-Note ".env present: $envFile"
}

Write-Note "workspace:  $Workspace"
Write-Note "build type: $BuildType"
Write-Note "target:     $TargetOs / $TargetCpu"

# --- Stage 1: init --------------------------------------------------------
if (-not $SkipInit) {
    Write-Host ''
    Write-Host '--------------------------------------------------------------' -ForegroundColor Yellow
    Write-Host ' STAGE 1: pnpm run init' -ForegroundColor Yellow
    Write-Host ' Downloads depot_tools, writes .gclient, runs gclient sync' -ForegroundColor DarkGray
    Write-Host ' (Chromium + ~240 repositories, ~60 GB), applies patches.' -ForegroundColor DarkGray
    Write-Host ' This can take a very long time. Do not interrupt it.' -ForegroundColor DarkGray
    Write-Host '--------------------------------------------------------------' -ForegroundColor Yellow

    $initArgs = @('--init')
    if ($TargetOs)  { $initArgs += "--target_os=$TargetOs" }
    if ($TargetCpu) { $initArgs += "--target_arch=$TargetCpu" }

    # Upstream's `init` script is: pnpm install --frozen-lockfile && node ./build/commands/scripts/sync.ts --init
    if (-not $SkipDeps) {
        Invoke-InBraveCore 'pnpm install --frozen-lockfile'
    }
    Invoke-InBraveCore ("node ./build/commands/scripts/sync.ts " + ($initArgs -join ' '))

    # Capture the real revision lock as early as it exists.
    $entries = Join-Path $Workspace '.gclient_entries'
    if (Test-Path $entries) {
        $lockDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'upstream\lock'
        if (-not (Test-Path $lockDir)) { New-Item -ItemType Directory -Force -Path $lockDir | Out-Null }
        $stamp   = Get-Date -Format 'yyyy-MM-dd'
        $version = (Get-Content (Join-Path $srcBrave 'package.json') -Raw | ConvertFrom-Json).version
        $lockFile = Join-Path $lockDir "$stamp-brave-core-$version-gclient-entries.txt"
        Copy-Item $entries $lockFile -Force
        Write-Note "captured revision lock: upstream\lock\$(Split-Path -Leaf $lockFile)"
    }
} else {
    Write-Note 'Skipping init (source already fetched).'
}

# --- Stage 2: build -------------------------------------------------------
Write-Host ''
Write-Host '--------------------------------------------------------------' -ForegroundColor Yellow
Write-Host " STAGE 2: pnpm run build $BuildType" -ForegroundColor Yellow
Write-Host ' GN configure + compile. Hours. Memory hungry.' -ForegroundColor DarkGray
Write-Host '--------------------------------------------------------------' -ForegroundColor Yellow

if (-not $SkipDeps) {
    Invoke-InBraveCore 'pnpm install --frozen-lockfile'
}
Invoke-InBraveCore "node ./build/commands/scripts/build.ts $BuildType"

# --- Report ---------------------------------------------------------------
Write-Step 'Done'

$outDir = Join-Path $Workspace "out\$($BuildType)_$TargetOs"
if (Test-Path $outDir) {
    Write-Note "output: $outDir"
} else {
    Write-Note "build completed; expected output under $outDir"
}

Write-Host ''
Write-Host 'Build finished.' -ForegroundColor Green
Write-Host ''
Write-Host 'Next:' -ForegroundColor Cyan
Write-Host "  .\scripts\run.ps1 -BuildType $BuildType"
Write-Host ''
Write-Host 'Run the browser from cmd.exe or Explorer, not from Cygwin/Git Bash:' -ForegroundColor DarkGray
Write-Host 'debug builds write to stderr and crash in those shells.' -ForegroundColor DarkGray
Write-Host ''
