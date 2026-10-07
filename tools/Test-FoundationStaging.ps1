<#
.SYNOPSIS
Runs real-artifact collision/selection tests; does not certify runner or signature trust.
#>
param(
    [Parameter(Mandatory)][string] $ArtifactFolder,
    [Parameter(Mandatory)][string] $FixtureFolder
)
$ErrorActionPreference = 'Stop'
$previousArtifacts = $env:FOUNDATION_STAGING_ARTIFACTS
$previousFixtures = $env:APPSOURCE_GATE_FIXTURES
try {
    $env:FOUNDATION_STAGING_ARTIFACTS = (Resolve-Path -LiteralPath $ArtifactFolder).Path
    $env:APPSOURCE_GATE_FIXTURES = (Resolve-Path -LiteralPath $FixtureFolder).Path
    $python = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command python -ErrorAction Stop }
    & $python.Source -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p 'test_foundation_staging.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'Foundation staging regression checks failed.' }
}
finally {
    $env:FOUNDATION_STAGING_ARTIFACTS = $previousArtifacts
    $env:APPSOURCE_GATE_FIXTURES = $previousFixtures
}
