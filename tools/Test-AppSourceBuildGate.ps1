<#
.SYNOPSIS
Runs compiler/parser/NAVX/receipt regressions with real compiler-produced input packages.
#>
param(
    [Parameter(Mandatory)][string] $FixtureFolder,
    [Parameter(Mandatory)][string] $FoundationPackage
)
$ErrorActionPreference = 'Stop'
$previousFixtures = $env:APPSOURCE_GATE_FIXTURES
$previousFoundation = $env:APPSOURCE_GATE_FOUNDATION
try {
    $env:APPSOURCE_GATE_FIXTURES = (Resolve-Path -LiteralPath $FixtureFolder).Path
    $env:APPSOURCE_GATE_FOUNDATION = (Resolve-Path -LiteralPath $FoundationPackage).Path
    $python = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $python) {
        $python = Get-Command python -ErrorAction Stop
    }
    & $python.Source -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p 'test_appsource_gate.py' -v
    if ($LASTEXITCODE -ne 0) {
        throw 'AppSource gate regression checks failed.'
    }
}
finally {
    $env:APPSOURCE_GATE_FIXTURES = $previousFixtures
    $env:APPSOURCE_GATE_FOUNDATION = $previousFoundation
}
