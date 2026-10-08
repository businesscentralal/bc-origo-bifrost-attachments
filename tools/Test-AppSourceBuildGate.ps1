<#
.SYNOPSIS
Runs compiler/parser/NAVX/receipt regressions with real compiler-produced input packages.
#>
param(
    [Parameter(Mandatory)][string] $FixtureFolder,
    [Parameter(Mandatory)][string] $FoundationPackage,
    [Parameter(Mandatory)][string] $CandidateFoundationPackage,
    [Parameter(Mandatory)][string] $MeasuredBasePackage,
    [Parameter(Mandatory)][string] $ReadyToRunAnyPackage,
    [Parameter(Mandatory)][string] $EmbeddedAnyPackage,
    [Parameter(Mandatory)][string] $ReadyToRunBasePackage,
    [Parameter(Mandatory)][string] $ReadyToRunBase55975Package,
    [Parameter(Mandatory)][string] $EmbeddedBase55975Package
)
$ErrorActionPreference = 'Stop'
$previousFixtures = $env:APPSOURCE_GATE_FIXTURES
$previousFoundation = $env:APPSOURCE_GATE_FOUNDATION
$previousCandidate = $env:APPSOURCE_GATE_FOUNDATION530
$previousBase = $env:APPSOURCE_GATE_BASE29
$previousReadyToRun = @{}
$readyToRunInputs = @{
    APPSOURCE_GATE_READYTORUN_ANY = $ReadyToRunAnyPackage
    APPSOURCE_GATE_EMBEDDED_ANY = $EmbeddedAnyPackage
    APPSOURCE_GATE_READYTORUN_BASE29 = $ReadyToRunBasePackage
    APPSOURCE_GATE_READYTORUN_BASE55975 = $ReadyToRunBase55975Package
    APPSOURCE_GATE_EMBEDDED_BASE55975 = $EmbeddedBase55975Package
}
foreach ($name in $readyToRunInputs.Keys) {
    $previousReadyToRun[$name] = [Environment]::GetEnvironmentVariable($name)
}
try {
    $env:APPSOURCE_GATE_FIXTURES = (Resolve-Path -LiteralPath $FixtureFolder).Path
    $env:APPSOURCE_GATE_FOUNDATION = (Resolve-Path -LiteralPath $FoundationPackage).Path
    $env:APPSOURCE_GATE_FOUNDATION530 = (Resolve-Path -LiteralPath $CandidateFoundationPackage).Path
    $env:APPSOURCE_GATE_BASE29 = (Resolve-Path -LiteralPath $MeasuredBasePackage).Path
    foreach ($name in $readyToRunInputs.Keys) {
        [Environment]::SetEnvironmentVariable($name, (Resolve-Path -LiteralPath $readyToRunInputs[$name]).Path)
    }
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
    & $python.Source -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p 'test_symbol_dedup.py' -v
    if ($LASTEXITCODE -ne 0) {
        throw 'Compiler catalog alias preparation regression checks failed.'
    }
    & $python.Source -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p 'test_ready_to_run.py' -v
    if ($LASTEXITCODE -ne 0) {
        throw 'ReadyToRun inventory regression checks failed.'
    }
    & $python.Source -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p 'test_measured_base55975.py' -v
    if ($LASTEXITCODE -ne 0) {
        throw 'Measured Base55975 regression checks failed.'
    }
}
finally {
    $env:APPSOURCE_GATE_FIXTURES = $previousFixtures
    $env:APPSOURCE_GATE_FOUNDATION = $previousFoundation
    $env:APPSOURCE_GATE_FOUNDATION530 = $previousCandidate
    $env:APPSOURCE_GATE_BASE29 = $previousBase
    foreach ($name in $previousReadyToRun.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previousReadyToRun[$name])
    }
}
