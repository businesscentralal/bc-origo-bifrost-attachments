<#
.SYNOPSIS
Runs compiler/parser/NAVX/receipt regressions with real compiler-produced input packages.
#>
param(
    [Parameter(Mandatory)][string] $FixtureFolder,
    [Parameter(Mandatory)][string] $FoundationPackage,
    [Parameter(Mandatory)][string] $CandidateFoundationPackage,
    [Parameter(Mandatory)][string] $MeasuredBasePackage
)
$ErrorActionPreference = 'Stop'
$previousFixtures = $env:APPSOURCE_GATE_FIXTURES
$previousFoundation = $env:APPSOURCE_GATE_FOUNDATION
$previousCandidate = $env:APPSOURCE_GATE_FOUNDATION530
$previousBase = $env:APPSOURCE_GATE_BASE29
try {
    $env:APPSOURCE_GATE_FIXTURES = (Resolve-Path -LiteralPath $FixtureFolder).Path
    $env:APPSOURCE_GATE_FOUNDATION = (Resolve-Path -LiteralPath $FoundationPackage).Path
    $env:APPSOURCE_GATE_FOUNDATION530 = (Resolve-Path -LiteralPath $CandidateFoundationPackage).Path
    $env:APPSOURCE_GATE_BASE29 = (Resolve-Path -LiteralPath $MeasuredBasePackage).Path
    $python = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $python) {
        $python = Get-Command python -ErrorAction Stop
    }
    & $python.Source -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p 'test_appsource_gate.py' -v
    if ($LASTEXITCODE -ne 0) {
        throw 'AppSource gate regression checks failed.'
    }
    & $python.Source -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p 'test_symbol_policy.py' -v
    if ($LASTEXITCODE -ne 0) {
        throw 'Bounded symbol policy regression checks failed.'
    }
}
finally {
    $env:APPSOURCE_GATE_FIXTURES = $previousFixtures
    $env:APPSOURCE_GATE_FOUNDATION = $previousFoundation
    $env:APPSOURCE_GATE_FOUNDATION530 = $previousCandidate
    $env:APPSOURCE_GATE_BASE29 = $previousBase
}
