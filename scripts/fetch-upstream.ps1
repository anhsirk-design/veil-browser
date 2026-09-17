<#
.SYNOPSIS
    Fetch the pinned brave-core revision into the Veil build workspace.

.DESCRIPTION
    Clones (or updates) brave-core into <Workspace>\src\brave, which is the exact
    location upstream requires.

    This does NOT download Chromium. Chromium is fetched by `gclient sync`, which
    brave-core bootstraps itself during `pnpm run init` (see scripts/build.ps1).
    Keeping the two steps separate means a brave-core clone failure is
    distinguishable from a 60 GB gclient failure.

.PARAMETER Workspace
    Build workspace. Defaults to $env:VEIL_WORKSPACE, then C:\veil-build.

.PARAMETER Ref
    brave-core ref to check out. Defaults to the ref in upstream/versions.json.

.PARAMETER Force
    Discard local changes in src/brave and re-checkout the pinned revision.

.EXAMPLE
    .\scripts\fetch-upstream.ps1
    .\scripts\fetch-upstream.ps1 -Workspace C:\veil-build
#>

[CmdletBinding()]
param(
    [string]$Workspace = $(if ($env:VEIL_WORKSPACE) { $env:VEIL_WORKSPACE } else { 'C:\veil-build' }),
    [string]$Ref,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path -Parent $PSScriptRoot
$versionsPath = Join-Path $repoRoot 'upstream\versions.json'

function Write-Step([string]$Text) { Write-Host "`n== $Text ==" -ForegroundColor Cyan }
function Write-Note([string]$Text) { Write-Host "   $Text" -ForegroundColor DarkGray }

Write-Host ''
Write-Host 'Veil - fetch upstream (brave-core)' -ForegroundColor White

# --- Read the pin ---------------------------------------------------------
Write-Step 'Reading pins'

if (-not (Test-Path $versionsPath)) {
    throw "Cannot find $versionsPath. Run this script from the Veil repository."
}

$versions  = Get-Content $versionsPath -Raw | ConvertFrom-Json
$braveCore = $versions.upstreams.'brave-core'

$cloneUrl  = $braveCore.clone_url
$pinnedRef = if ($Ref) { $Ref } else { $braveCore.ref }
$dir       = $braveCore.workspace_dir   # "src/brave"

Write-Note "repo:      $cloneUrl"
Write-Note "ref:       $pinnedRef"
Write-Note "version:   $($braveCore.version)"
Write-Note "target:    $Workspace\$($dir -replace '/', '\')"

# --- Path sanity ----------------------------------------------------------
Write-Step 'Validating workspace path'

if ($Workspace -match '\s') {
    throw "Workspace path contains a space ('$Workspace'). Chromium build tools cannot handle this. Use e.g. C:\veil-build"
}

if (-not ($Workspace -match '^[A-Za-z]:\\[^\\]+$' -or $Workspace -match '^/')) {
    Write-Warning "Workspace is not at a drive root. Upstream strongly recommends a top-level path."
}

# --- Create the layout ----------------------------------------------------
Write-Step 'Preparing workspace layout'

$srcBrave = Join-Path $Workspace ($dir -replace '/', '\')
$srcDir   = Join-Path $Workspace 'src'

foreach ($p in @($Workspace, $srcDir, (Join-Path $Workspace 'vendor'))) {
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Force -Path $p | Out-Null
        Write-Note "created $p"
    } else {
        Write-Note "exists  $p"
    }
}

# --- Clone or update ------------------------------------------------------
Write-Step 'Fetching brave-core'

if (Test-Path (Join-Path $srcBrave '.git')) {
    Write-Note 'brave-core is already cloned; updating.'
    Push-Location $srcBrave
    try {
        if ($Force) {
            git fetch --all --tags
            git checkout --force $pinnedRef
            git reset --hard $pinnedRef
        } else {
            git fetch origin
            $current = (git rev-parse --abbrev-ref HEAD).Trim()
            if ($current -ne $pinnedRef) {
                Write-Note "currently on '$current', checking out '$pinnedRef'"
                git checkout $pinnedRef
            }
            git pull --ff-only
        }
        Write-Note "now at: $(git rev-parse --short HEAD)"
    } finally {
        Pop-Location
    }
} else {
    if (Test-Path $srcBrave) {
        $existing = Get-ChildItem -Force $srcBrave -ErrorAction SilentlyContinue
        if ($existing) {
            throw "$srcBrave exists and is not a git checkout but is not empty. Refusing to overwrite. Move it aside and re-run."
        }
    }
    Write-Note "cloning into $srcBrave"
    git clone $cloneUrl $srcBrave
    Push-Location $srcBrave
    try {
        if ($pinnedRef -and $pinnedRef -ne 'HEAD') { git checkout $pinnedRef }
        Write-Note "HEAD: $(git rev-parse --short HEAD)"
    } finally {
        Pop-Location
    }
}

# --- Report ---------------------------------------------------------------
Write-Step 'Done'

Push-Location $srcBrave
try {
    $head    = (git rev-parse HEAD).Trim()
    $subject = (git log -1 --pretty=format:'%s').Trim()
    $desc    = (git describe --tags --always 2>$null)
} finally {
    Pop-Location
}

Write-Note "commit:  $head"
Write-Note "describe: $desc"
Write-Note "subject: $subject"

Write-Host ''
Write-Host 'brave-core is in place. Chromium has NOT been downloaded yet.' -ForegroundColor Yellow
Write-Host 'Chromium (~60 GB) is fetched by gclient during `pnpm run init`,' -ForegroundColor DarkGray
Write-Host 'which scripts/build.ps1 runs for you.' -ForegroundColor DarkGray
Write-Host ''
Write-Host 'Next:' -ForegroundColor Cyan
Write-Host "  1. Copy .env.example to $srcBrave\.env  (review it first)"
Write-Host '  2. .\scripts\build.ps1'
Write-Host ''
Write-Host 'After the build, snapshot src/brave''s resolved deps:' -ForegroundColor DarkGray
Write-Host "  $Workspace\.gclient_entries  ->  upstream\lock\" -ForegroundColor DarkGray
Write-Host ''
