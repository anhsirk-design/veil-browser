<#
.SYNOPSIS
    Launch the built Veil browser.

.DESCRIPTION
    Runs brave-core's start command inside <Workspace>\src\brave.

    IMPORTANT: launch from a plain cmd.exe window or from Explorer. Debug builds
    write to stderr, and that crashes under Cygwin or Git Bash.

.PARAMETER Workspace
    Build workspace. Defaults to $env:VEIL_WORKSPACE, then C:\veil-build.

.PARAMETER BuildType
    component (default) | Release | Static | Debug - must match the build you made.

.PARAMETER Arguments
    Extra arguments passed through to the browser binary.

.EXAMPLE
    .\scripts\run.ps1
    .\scripts\run.ps1 -BuildType Release
#>

[CmdletBinding()]
param(
    [string]$Workspace = $(if ($env:VEIL_WORKSPACE) { $env:VEIL_WORKSPACE } else { 'C:\veil-build' }),
    [ValidateSet('component', 'Component', 'Release', 'Static', 'Debug')]
    [string]$BuildType = 'Component',
    [string[]]$Arguments = @()
)

$ErrorActionPreference = 'Stop'

$srcBrave = Join-Path $Workspace 'src\brave'

function Write-Step([string]$Text) { Write-Host "`n== $Text ==" -ForegroundColor Cyan }
function Write-Note([string]$Text) { Write-Host "   $Text" -ForegroundColor DarkGray }

Write-Host ''
Write-Host 'Veil - run' -ForegroundColor White

Write-Step 'Checking build'

if (-not (Test-Path $srcBrave)) {
    throw "brave-core not found at $srcBrave. Run scripts/fetch-upstream.ps1 first."
}

$outDir = Join-Path $Workspace "out\$($BuildType)_windows"
if (Test-Path $outDir) {
    Write-Note "output dir: $outDir"
} else {
    Write-Warning "No build output at $outDir - have you run scripts/build.ps1 -BuildType $BuildType ?"
}

Write-Note "build type: $BuildType"

Write-Step 'Starting'

Push-Location $srcBrave
try {
    $cmd = "node ./build/commands/scripts/commands.js start $BuildType"
    if ($Arguments.Count -gt 0) { $cmd += ' ' + ($Arguments -join ' ') }
    Write-Note "> $cmd"
    & cmd.exe /c $cmd
} finally {
    Pop-Location
}
