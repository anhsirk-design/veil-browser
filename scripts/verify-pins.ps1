<#
.SYNOPSIS
    Verify that the pinned upstream revisions in upstream/versions.json are
    reachable and valid.

.DESCRIPTION
    A lightweight, network-only check. It does NOT download source and does NOT
    touch the build workspace. It answers one question:

        "Do the revisions we claim to build on actually exist upstream?"

    Checks performed:
      * brave-core ref resolves on github.com/brave/brave-core
      * the pinned version string appears in brave-core's package.json
      * the pinned Chromium tag resolves on
        chromium.googlesource.com/chromium/src
      * depot_tools ref resolves

.PARAMETER Quiet
    Only print failures and the final verdict.

.EXAMPLE
    .\scripts\verify-pins.ps1
#>

[CmdletBinding()]
param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'

$repoRoot     = Split-Path -Parent $PSScriptRoot
$versionsPath = Join-Path $repoRoot 'upstream\versions.json'

$script:Failures = 0

function Write-Step([string]$Text) { if (-not $Quiet) { Write-Host "`n== $Text ==" -ForegroundColor Cyan } }
function Pass([string]$Text) { if (-not $Quiet) { Write-Host "  [ ok ] $Text" -ForegroundColor Green } }
function Info([string]$Text) { if (-not $Quiet) { Write-Host "         $Text" -ForegroundColor DarkGray } }
function Fail([string]$Text) { Write-Host "  [FAIL] $Text" -ForegroundColor Red; $script:Failures++ }

function Test-RemoteRef([string]$Url, [string]$Ref) {
    $out = & git ls-remote $Url $Ref 2>$null
    return [bool]($out -and $out.Trim().Length -gt 0)
}

# git ls-remote against googlesource enumerates an enormous ref list and can
# hang for minutes. For googlesource hosts we use the +/refs/...?format=JSON
# endpoint instead, which answers in a single request.
function Test-GooglesourceRef([string]$RepoUrl, [string]$Ref) {
    $base = $RepoUrl -replace '\.git$', ''
    $uri  = "$base/+/$Ref`?format=JSON"
    try {
        $resp = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        return ($resp.StatusCode -eq 200)
    } catch {
        $code = $null
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        if ($code -eq 404) { return $false }
        return $false
    }
}

Write-Host ''
Write-Host 'Veil - verify upstream pins' -ForegroundColor White
Write-Host 'Read-only. No source is downloaded.' -ForegroundColor DarkGray

if (-not (Test-Path $versionsPath)) {
    Write-Host "Cannot find $versionsPath" -ForegroundColor Red
    exit 1
}

$versions = Get-Content $versionsPath -Raw | ConvertFrom-Json

# --- brave-core -----------------------------------------------------------
Write-Step 'brave-core'

$bc       = $versions.upstreams.'brave-core'
$bcUrl    = $bc.repo
$bcRef    = $bc.ref
$bcVer    = $bc.version

if (Test-RemoteRef $bcUrl "refs/heads/$bcRef") {
    Pass "ref '$bcRef' resolves on $bcUrl"
} else {
    Fail "ref '$bcRef' does NOT resolve on $bcUrl"
}

# Confirm the version string actually matches upstream's package.json.
try {
    $rawUrl  = "https://raw.githubusercontent.com/brave/brave-core/$bcRef/package.json"
    $pkgRaw  = Invoke-WebRequest -Uri $rawUrl -UseBasicParsing -TimeoutSec 30
    $pkg     = $pkgRaw.Content | ConvertFrom-Json

    if ($pkg.version -eq $bcVer) {
        Pass "package.json version matches pin: $($pkg.version)"
    } else {
        Fail "pin says version '$bcVer' but upstream package.json says '$($pkg.version)'. Re-pin."
    }

    $chromeTag = $pkg.config.projects.chrome.tag
    $chromeRepo = $pkg.config.projects.chrome.repository

    if ($chromeTag) {
        Pass "upstream declares Chromium tag: $chromeTag"
    } else {
        Fail 'upstream package.json does not declare config.projects.chrome.tag'
    }

    # Compare against our recorded Chromium pin.
    if ($chromeTag -and $chromeTag -ne $versions.upstreams.chromium.tag) {
        Fail "Chromium pin mismatch: versions.json says '$($versions.upstreams.chromium.tag)', upstream says '$chromeTag'"
    } elseif ($chromeTag) {
        Pass 'recorded Chromium pin matches upstream'
    }

    if ($chromeRepo -and $chromeRepo -ne $versions.upstreams.chromium.repo) {
        Info "upstream Chromium repository: $chromeRepo"
    }
} catch {
    Fail "could not read upstream package.json: $($_.Exception.Message)"
}

# --- Chromium -------------------------------------------------------------
Write-Step 'Chromium'

$cr    = $versions.upstreams.chromium
$crTag = $cr.tag

Info 'using the googlesource ref endpoint (git ls-remote is impractically slow there)'
if (Test-GooglesourceRef $cr.repo "refs/tags/$crTag") {
    Pass "tag '$crTag' resolves on $($cr.repo)"
} else {
    Fail "tag '$crTag' does NOT resolve on $($cr.repo)"
}

# --- depot_tools ----------------------------------------------------------
Write-Step 'depot_tools'

$dt = $versions.upstreams.depot_tools
if (Test-GooglesourceRef $dt.repo "refs/heads/$($dt.ref)") {
    Pass "ref '$($dt.ref)' resolves on $($dt.repo)"
} else {
    Fail "ref '$($dt.ref)' does NOT resolve on $($dt.repo)"
}

# --- adblock-rust ---------------------------------------------------------
Write-Step 'adblock-rust (resolved transitively)'

if (Test-RemoteRef $versions.upstreams.'adblock-rust'.repo 'HEAD') {
    Pass 'repository reachable (exact revision is resolved by brave-core at sync time)'
} else {
    Fail 'repository not reachable'
}

# --- Verdict --------------------------------------------------------------
Write-Host ''
if ($script:Failures -eq 0) {
    Write-Host 'All pins verified reachable and consistent.' -ForegroundColor Green
    Write-Host ''
    exit 0
} else {
    Write-Host "$($script:Failures) pin problem(s) found." -ForegroundColor Red
    Write-Host 'Update upstream/versions.json, or investigate upstream changes.' -ForegroundColor Red
    Write-Host ''
    exit 1
}
