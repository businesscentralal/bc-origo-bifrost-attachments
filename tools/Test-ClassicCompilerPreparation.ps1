<#
.SYNOPSIS
Runs bounded preparation and genuine helper-selection equivalence checks.
.DESCRIPTION
Requires retained official source, full genuine catalog and a metadata runtime.
Fixtures are owner-local tooling proof, not product compile or runtime evidence.
#>
param(
    [string] $SourceFolder = $env:FOUNDATION_CLASSIC_HELPER_SOURCE,
    [string] $CatalogFolder = $env:FOUNDATION_CLASSIC_CATALOG,
    [string] $CompilerExtension = $env:FOUNDATION_CLASSIC_COMPILER_EXTENSION,
    [string] $DotNetFolder = $env:FOUNDATION_CLASSIC_DOTNET_FOLDER,
    [string] $EvidenceFolder = $env:FOUNDATION_CLASSIC_EVIDENCE,
    [string] $TelemetrySource = $env:FOUNDATION_CLASSIC_TELEMETRY_SOURCE
)
$ErrorActionPreference = 'Stop'
foreach ($path in $SourceFolder,$CatalogFolder,$CompilerExtension,$DotNetFolder,$EvidenceFolder) {
    if (-not $path) { throw 'Mandatory genuine fixed-point input absent.' }
}
$repo = Split-Path $PSScriptRoot -Parent
$env:FOUNDATION_CLASSIC_HELPER_SOURCE = $SourceFolder
$env:FOUNDATION_CLASSIC_CATALOG = $CatalogFolder
$env:FOUNDATION_CLASSIC_ALTOOL = Join-Path $CompilerExtension 'bin/altool.dll'
$env:FOUNDATION_CLASSIC_DOTNET = Join-Path $DotNetFolder $(if ($IsWindows) {'dotnet.exe'} else {'dotnet'})
$env:FOUNDATION_CLASSIC_EVIDENCE = $EvidenceFolder
& python3 -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p 'test_classic_preparation.py' -v
if ($LASTEXITCODE -ne 0) { throw 'Bounded preparation regressions failed.' }
# Execute the unchanged exact official selection block and genuine GetAppInfo.
$helper = Join-Path $SourceFolder 'CompilerFolderHandling/Compile-AppWithBcCompilerFolder.ps1'
if ((Get-FileHash $helper).Hash.ToLowerInvariant() -cnotin @('9835753336bc95bc3cac0813e50ef06da4b4132fa1aee116c65934751abdad2d','9bdc072429580d8b78ed68eabbc537e07df0e7c5d49bed1131f0bf5dbab672d7')) { throw 'Unpinned helper source.' }
$tokens=$null; $errors=$null
$metadataSource=Join-Path $SourceFolder 'GetAppInfo-source.ps1'
$ast=[System.Management.Automation.Language.Parser]::ParseFile($metadataSource,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw 'Metadata source parse failed.' }
foreach ($name in 'CmdDo','GetAppInfo') {
    $node=$ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $name}.GetNewClosure(),$true)
    if (-not $node) { throw 'Genuine helper function absent.' }
    Invoke-Expression $node.Extent.Text
}
# Load the unmodified official telemetry function; a null fixture scope emits nothing.
if (-not $TelemetrySource -or (Get-FileHash $TelemetrySource).Hash.ToLowerInvariant() -cne '4e53227a290d1d087d6658e95c85f18f222c9620c47db8e89149fbd9aa8d1e14') { throw 'Pinned telemetry dependency absent.' }
$telemetryAst=[System.Management.Automation.Language.Parser]::ParseFile($TelemetrySource,[ref]$tokens,[ref]$errors)
$telemetryNode=$telemetryAst.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'AddTelemetryProperty'},$true)
if ($errors.Count -or -not $telemetryNode) { throw 'Official telemetry dependency parse failed.' }
Invoke-Expression $telemetryNode.Extent.Text
$source = Get-Content $helper -Raw
$begin=$source.IndexOf('        $dependencies = @()')
$end=$source.IndexOf('        $systemSymbolsApp =', $begin)
if ($begin -lt 0 -or $end -lt $begin) { throw 'Selection block absent.' }
$prepare=[scriptblock]::Create($source.Substring($begin,$end-$begin))
$temp=Join-Path ([IO.Path]::GetTempPath()) ('classic-graph-'+[guid]::NewGuid())
$originalPath=$env:PATH; $originalDotNet=$env:DOTNET_ROOT
try {
    $compilerFolder=Join-Path $temp 'compilerFolder'; $appSymbolsFolder=Join-Path $temp 'cache'
    $symbolsPath=Join-Path $compilerFolder 'symbols'
    New-Item -ItemType Directory -Path $appSymbolsFolder,(Join-Path $compilerFolder 'symbols'),(Join-Path $compilerFolder 'compiler') -Force | Out-Null
    # A private link to the unchanged immutable compiler, never editing it.
    New-Item -ItemType SymbolicLink -Path (Join-Path $compilerFolder 'compiler/extension') -Target $CompilerExtension | Out-Null
    Copy-Item (Join-Path $CatalogFolder '*.app') (Join-Path $compilerFolder 'symbols')
    Copy-Item $env:FOUNDATION_CLASSIC_PACKAGE (Join-Path $appSymbolsFolder 'foundation.app')
    $env:PATH=$DotNetFolder+[IO.Path]::PathSeparator+$env:PATH; $env:DOTNET_ROOT=$DotNetFolder
    $appJsonObject=Get-Content (Join-Path $repo 'app/app.json') -Raw | ConvertFrom-Json
    function Get-Inventory {
        @(Get-ChildItem $appSymbolsFolder -File -Filter '*.app' | Sort-Object Name | ForEach-Object { @{file=$_.Name;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()} })
    }
    $observations=@()
    foreach ($iteration in 1,2,3) {
        # Cache freshness is meaningful: remove only this exclusive run-local cache.
        if ($iteration -eq 1) { Remove-Item (Join-Path $appSymbolsFolder 'cache_AppInfo.json'),(Join-Path $compilerFolder 'symbols/cache_AppInfo.json') -Force -ErrorAction SilentlyContinue }
        . $prepare
        $inventory=@(Get-Inventory)
        foreach ($dep in $dependencies) {
            if (-not ($existingApps | Where-Object { $_.AppId -eq $dep.AppId -and [version]$_.Version -ge [version]$dep.Version })) { throw 'Actual helper graph unresolved.' }
        }
        if ($iteration -gt 1 -and ($inventory|ConvertTo-Json -Depth 10 -Compress) -cne ($previous|ConvertTo-Json -Depth 10 -Compress)) { throw 'Actual helper graph not a fixed point.' }
        $observations += @{iteration=$iteration;inventory=$inventory;dependencyCount=$dependencies.Count}
        $previous=$inventory
    }
    $ownedModel=Get-Content (Join-Path $EvidenceFolder 'prepared-receipt.json') -Raw | ConvertFrom-Json
    $model=@($ownedModel.cache | ForEach-Object {@{file=$_.file;sha256=$_.sha256}} | Sort-Object { $_.file })
    if (($model|ConvertTo-Json -Depth 10 -Compress) -cne ($previous|ConvertTo-Json -Depth 10 -Compress)) { throw 'Owned model disagrees with unchanged helper graph.' }
    @{helperSha256=(Get-FileHash $helper).Hash.ToLowerInvariant(); metadataSourceSha256=(Get-FileHash $metadataSource).Hash.ToLowerInvariant(); genuineMetadata=$true; actualProductManifestSha256=(Get-FileHash (Join-Path $repo 'app/app.json')).Hash.ToLowerInvariant(); observations=$observations; selectedPackages=$model; modelMatches=$true; consumedInputsCertified=$false; runtimeRunnerProof=$false; testCurrentProductVerified=$false; scope='Retained product-manifest Foundation/Microsoft graph only; paired Windows/Test product still required.'} | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $EvidenceFolder 'helper-full-graph.json')
    Write-Host 'Genuine helper full retained product graph: fresh preparation and two replays match owned model; no runner/Test-product certification.'
}
finally {
    $env:PATH=$originalPath; $env:DOTNET_ROOT=$originalDotNet
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
