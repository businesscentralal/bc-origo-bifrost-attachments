<#
.SYNOPSIS
Runs real-artifact collision/selection tests; does not certify runner or signature trust.
Supply ArtifactFolder/FOUNDATION_STAGING_ARTIFACTS, FixtureFolder/APPSOURCE_GATE_FIXTURES,
CandidateArtifactFolder/FOUNDATION_CANDIDATE_ARTIFACTS, UpstreamFolder/FOUNDATION_ADAPTER_UPSTREAM
and PowerShellHost/FOUNDATION_ADAPTER_PWSH. Missing genuine inputs always fail.
#>
param(
    [string] $ArtifactFolder = $env:FOUNDATION_STAGING_ARTIFACTS,
    [string] $FixtureFolder = $env:APPSOURCE_GATE_FIXTURES,
    [string] $CandidateArtifactFolder = $env:FOUNDATION_CANDIDATE_ARTIFACTS,
    [string] $UpstreamFolder = $env:FOUNDATION_ADAPTER_UPSTREAM,
    [string] $PowerShellHost = $env:FOUNDATION_ADAPTER_PWSH
)
$ErrorActionPreference = 'Stop'
foreach ($entry in @{ArtifactFolder=$ArtifactFolder; FixtureFolder=$FixtureFolder; CandidateArtifactFolder=$CandidateArtifactFolder; UpstreamFolder=$UpstreamFolder; PowerShellHost=$PowerShellHost}.GetEnumerator()) {
    if (-not $entry.Value -or -not (Test-Path -LiteralPath $entry.Value)) { throw "Missing genuine staging input: $($entry.Key). Supply explicit parameter or documented environment." }
}
# Immutable AL-Go f192c6a6 source inputs used by the native consumer matrix.
$upstreamHashes = @{
    'AL-Go-Helper.ps1' = 'e3c5488ae4d52cd7b38867b50002752b75531bac71c4900cdd28e9aaf97c02f2'
    'CompileApps/Compile.ps1' = '16e2056d9fc88097bf10c504886ff2d2bfccf4d91796cc62cc271cf20df438d9'
    'CompileApps/action.yaml' = '935ab940ee7fb7a21ad660ad44a879af9b598ff426b518b163d471f61d6586c0'
    'DownloadProjectDependencies/ComputeDependencyArtifactPattern.ps1' = 'c686007441401b77d92e41ac7dcbbc9821cd7c7e9a9e009bfe159687d1199d50'
    'DownloadProjectDependencies/DownloadProjectDependencies.Action.ps1' = 'd8a12c84070bbcd753340e15002ef7f69996b39dea2b2e14cc0e15531de1abf3'
    'DownloadProjectDependencies/DownloadProjectDependencies.psm1' = 'c363b27a6aae2f277eed849e526114be1c9d4db970cec7340d39a1d895e18b3d'
    'DownloadProjectDependencies/action.yaml' = 'bfadb556a8615734d1bea69b00f0a88b9a10171d20779fe20e9485dfeeebb4c9'
    'RunPipeline/RunPipeline.ps1' = '30bbe399d5c74d7becee7b920fa797e335b399732c393224b136c03c9b18df76'
    'RunPipeline/action.yaml' = 'b872dc486a72066e17bf32edf4210ba4e15be090b7c13307b0c31404a665f0e4'
}
foreach ($entry in $upstreamHashes.GetEnumerator()) {
    $path = Join-Path $UpstreamFolder $entry.Key
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -cne $entry.Value) { throw "Missing/changed pinned staging source: $($entry.Key)" }
}
& $PowerShellHost -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()'
if ($LASTEXITCODE -ne 0) { throw 'Sanctioned PowerShell host invocation failed.' }
# Python validates exact archive/source hashes and the genuine integration contracts.
$previousUpstream = $env:FOUNDATION_ADAPTER_UPSTREAM
$previousHost = $env:FOUNDATION_ADAPTER_PWSH
$previousArtifacts = $env:FOUNDATION_STAGING_ARTIFACTS
$previousFixtures = $env:APPSOURCE_GATE_FIXTURES
$previousCandidateArtifacts = $env:FOUNDATION_CANDIDATE_ARTIFACTS
try {
    $env:FOUNDATION_ADAPTER_UPSTREAM = (Resolve-Path -LiteralPath $UpstreamFolder).Path
    $env:FOUNDATION_ADAPTER_PWSH = (Resolve-Path -LiteralPath $PowerShellHost).Path
    $env:FOUNDATION_STAGING_ARTIFACTS = (Resolve-Path -LiteralPath $ArtifactFolder).Path
    $env:APPSOURCE_GATE_FIXTURES = (Resolve-Path -LiteralPath $FixtureFolder).Path
    $env:FOUNDATION_CANDIDATE_ARTIFACTS = (Resolve-Path -LiteralPath $CandidateArtifactFolder).Path
    $python = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command python -ErrorAction Stop }
    & $python.Source -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p 'test_foundation_staging.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'Foundation staging regression checks failed.' }
}
finally {
    $env:FOUNDATION_ADAPTER_UPSTREAM = $previousUpstream
    $env:FOUNDATION_ADAPTER_PWSH = $previousHost
    $env:FOUNDATION_STAGING_ARTIFACTS = $previousArtifacts
    $env:APPSOURCE_GATE_FIXTURES = $previousFixtures
    $env:FOUNDATION_CANDIDATE_ARTIFACTS = $previousCandidateArtifacts
}
