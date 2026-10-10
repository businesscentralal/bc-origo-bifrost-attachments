param(
    [ValidateSet('Stage', 'Validate', 'PrepareManifest')][string] $Action,
    [string] $Root = $env:GITHUB_WORKSPACE,
    [string] $ArchiveManifestPath,
    [string] $DownloadedApps,
    [string] $DownloadedTestApps,
    [string[]] $CacheRoot = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# CompileApps creates a workspace before its PreCompileApp hook. Prepare the
# build-local product manifest here, never Foundation or test dependency manifests.
if ($Action -eq 'PrepareManifest') {
    if ($env:BuildMode -cnotin @('Default', 'Test')) { throw 'Unexpected build mode for manifest preparation.' }
    $path = Join-Path $Root 'app/app.json'
    $manifest = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $changed = $false
    if ($env:BuildMode -ceq 'Default') {
        if ($manifest.PSObject.Properties['internalsVisibleTo']) {
            $manifest.PSObject.Properties.Remove('internalsVisibleTo')
            $changed = $true
        }
        if ($manifest.PSObject.Properties['suppressWarnings'] -and 'AS0081' -in $manifest.suppressWarnings) {
            $manifest.suppressWarnings = @($manifest.suppressWarnings | Where-Object { $_ -ne 'AS0081' })
            $changed = $true
        }
    }
    if ($changed) { $manifest | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding UTF8 }
    # Test friendship and every unrelated property are preserved.
    return
}
$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction Stop }
$sha = & git -C $Root rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $sha -notmatch '^[a-f0-9]{40}$') { throw 'Missing checkout identity.' }
$context = @{run=$env:GITHUB_RUN_ID; attempt=$env:GITHUB_RUN_ATTEMPT; sourceCommit=$env:GITHUB_SHA; checkoutSha=$sha; mode=$env:BuildMode}
$destination = Join-Path $env:RUNNER_TEMP "foundation-selected-$env:GITHUB_RUN_ID-$env:GITHUB_RUN_ATTEMPT-$env:BuildMode"
function Read-FoundationArray {
    param([string] $Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Missing stock/selected dependency array.' }
    $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    foreach ($item in @($value)) { if ($item -isnot [string]) { throw 'Non-string dependency input.' } }
    return @($value)
}
function Invoke-FoundationStage {
    param([string] $Operation, $Request)
    $path = Join-Path $env:RUNNER_TEMP ([guid]::NewGuid().ToString() + '.json')
    try {
        $Request | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path -Encoding UTF8
        $diagnostics = @(& $python.Source (Join-Path $Root 'tools/stage_foundation_inputs.py') $Operation --input $path --destination $destination)
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0 -or $diagnostics.Count -ne 1 -or $diagnostics[0] -cne "Foundation input $Operation passed; signature trust not verified") { throw "Foundation $Operation refused." }
        $diagnostics | ForEach-Object { Write-Host $_ }
    }
    finally { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
}
if ($Action -eq 'Stage') {
    $manifest = Get-Content -LiteralPath $ArchiveManifestPath -Raw | ConvertFrom-Json
    if ($manifest.profile -cne 'candidate530') { throw 'Unexpected acquisition profile.' }
    Invoke-FoundationStage 'stage' @{profile='candidate530'; artifacts=$manifest.artifacts; context=$context; otherApps=@(Read-FoundationArray $DownloadedApps); otherTestApps=@(Read-FoundationArray $DownloadedTestApps)}
    $appsPath = Join-Path $destination 'installApps.json'
    $testsPath = Join-Path $destination 'installTestApps.json'
    Invoke-FoundationStage 'publish' @{context=$context; installApps=@(Read-FoundationArray $appsPath); installTestApps=@(Read-FoundationArray $testsPath); publicationRoot=(Join-Path $Root '.dependencies')}
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Encoding UTF8 -Value "InstallApps=$appsPath"
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Encoding UTF8 -Value "InstallTestApps=$testsPath"
}
else {
    $appsPath = Join-Path $destination 'installApps.json'
    $testsPath = Join-Path $destination 'installTestApps.json'
    Invoke-FoundationStage 'consumer' @{context=$context; installApps=@(Read-FoundationArray $appsPath); installTestApps=@(Read-FoundationArray $testsPath); cacheRoots=@($CacheRoot); root=$Root}
}
