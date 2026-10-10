<#
.SYNOPSIS
Prepares and rechecks bounded owner-local inputs for the unchanged helper6.1.18.
.DESCRIPTION
Fresh altool metadata and copied bytes are retained as operational evidence.
No helper/action mutation or compiler consumption certification is performed.
#>
param(
    [ValidateSet('Prepare', 'Seal', 'After')][string] $Action,
    [hashtable] $CompilationParams,
    [string[]] $AppFiles = @(),
    [string] $Root = $env:GITHUB_WORKSPACE
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$sha = & git -C $Root rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Missing checkout SHA.' }
$context = @{run=$env:GITHUB_RUN_ID; attempt=$env:GITHUB_RUN_ATTEMPT; job=$env:GITHUB_JOB; sourceCommit=$env:GITHUB_SHA; checkoutSha=$sha; mode=$env:BuildMode; project='.'; buildUrl="$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"}
$request = @{context=$context; appFiles=@($AppFiles); copyAppToSymbolsFolder=[bool]$CompilationParams['CopyAppToSymbolsFolder']}
if ($Action -eq 'Prepare') {
    & (Join-Path $Root 'tools/Prepare-FoundationInputs.ps1') -Action Validate -Root $Root -CacheRoot @($CompilationParams.appSymbolsFolder, (Join-Path $CompilationParams.compilerFolder 'symbols'))
    $helper = Get-Command Compile-AppWithBcCompilerFolder -ErrorAction Stop
    $bin = Join-Path $CompilationParams.compilerFolder 'compiler/extension/bin'
    $platform = if ($IsLinux) {'linux'} elseif ($IsMacOS) {'darwin'} else {'win32'}
    $platformBin = Join-Path $bin $platform
    if (-not (Test-Path (Join-Path $platformBin 'alc.*'))) { $platformBin = $bin }
    $altool = Join-Path $platformBin 'altool.exe'
    if ($IsLinux -or $IsMacOS) {
        $native = Join-Path $platformBin 'altool'
        if (Test-Path -LiteralPath $native) { $altool = $native }
        else { $altool = Join-Path $platformBin 'altool.dll' }
    }
    $request.compilerExtension = Split-Path $bin -Parent
    $request.compilerFolder = $CompilationParams.compilerFolder
    $metadataHelper = Get-Command GetAppInfo -ErrorAction Stop
    $request.metadataHelper = $metadataHelper.ScriptBlock.File
    $request.altool = $altool
    $request.altoolSha256 = (Get-FileHash -LiteralPath $altool -Algorithm SHA256).Hash.ToLowerInvariant()
    if ([IO.Path]::GetExtension($altool) -eq '.dll') {
        $request.dotnet = (Get-Command dotnet -ErrorAction Stop).Source
        $request.dotnetSha256 = (Get-FileHash -LiteralPath $request.dotnet -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $request.helper = $helper.ScriptBlock.File
    $request.ownedRoot = $env:RUNNER_TEMP
    $request.appProjectFolder = $CompilationParams.appProjectFolder
    $request.symbolsFolder = $CompilationParams.appSymbolsFolder
    $request.compilerSymbolsFolder = Join-Path $CompilationParams.compilerFolder 'symbols'
    $request.parameters = @{UpdateDependencies=[bool]$CompilationParams['UpdateDependencies']; GenerateReportLayout=[string]$CompilationParams['GenerateReportLayout']; customCodeCops=@($CompilationParams['customCodeCops']); assemblyProbingPaths=[string]$CompilationParams['assemblyProbingPaths']}
}
$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction Stop }
$path = Join-Path $env:RUNNER_TEMP ('classic-request-' + [guid]::NewGuid() + '.json')
$operation = @{Prepare='classic-prepare'; Seal='classic-seal'; After='classic-after'}[$Action]
try {
    $request | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path -Encoding UTF8
    $diagnostics = @(& $python.Source (Join-Path $Root 'tools/appsource_gate.py') $operation --root $Root --input $path)
    if ($LASTEXITCODE -ne 0 -or $diagnostics.Count -ne 1 -or $diagnostics[0] -cne "AppSource gate: $operation passed") { throw "Classic $Action preparation refused." }
    $diagnostics | ForEach-Object { Write-Host $_ }
}
finally { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
