<#
.SYNOPSIS
Runs stock Settings-seam and bounded acquisition tests with retained genuine inputs.
Mocked network delivery is not an authenticated runner/AL/BC verification.
#>
param(
    [Parameter(Mandatory)][string] $UpstreamFolder,
    [Parameter(Mandatory)][string] $CandidateArtifactFolder,
    [Parameter(Mandatory)][string] $MetadataFolder
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Acquire-FoundationInputs.ps1') -FunctionsOnly
$root = Split-Path $PSScriptRoot -Parent
$count = 0
function Assert-Adapter($Condition, $Message) { if (-not $Condition) { throw $Message }; $script:count++ }
function Assert-Refusal([scriptblock] $Action) {
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    Assert-Adapter $failed 'Expected bounded refusal.'
}
# Extract unmodified stock functions by AST, not a reimplementation of Settings behavior.
$tokens=$null; $errors=$null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $UpstreamFolder 'AL-Go-Helper.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Stock helper parse failed.' }
foreach ($name in 'AnalyzeRepo', 'CheckAppDependencyProbingPaths', 'Copy-HashTable', 'ConvertTo-HashTable') {
    $node = $ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $name}.GetNewClosure(), $true)
    if (-not $node) { throw 'Stock Settings seam absent.' }
    Invoke-Expression $node.Extent.Text
}
$resolverAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $UpstreamFolder 'DownloadProjectDependencies/DownloadProjectDependencies.Action.ps1'), [ref]$tokens, [ref]$errors)
$resolverNode = $resolverAst.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'DownloadDependenciesFromProbingPaths'}, $true)
if (-not $resolverNode) { throw 'Stock resolver seam absent.' }
Invoke-Expression $resolverNode.Extent.Text
function GetDependencies { param($probingPathsJson, $saveToPath) $script:observedProbes = $probingPathsJson; return 'unrelated-resolved.app' }
function Resolve-DependencyFiles { param($Dependencies, $DestinationPath) return $Dependencies }
$savedSettings = $env:Settings
# Only filesystem/platform ancillary functions are stubbed; stock AnalyzeRepo and
# CheckAppDependencyProbingPaths execute. Empty app folders isolate the Settings seam.
function ResolveProjectFolders { param($baseFolder, $project, $projectSettings) }
function OutputWarning { param($message) throw $message }
$ALGoSettingsFile = '.AL-Go/settings.json'
$testRunnerApps=@(); $testFrameworkApps=@(); $testLibrariesApps=@(); $performanceToolkitApps=@()
$original = Get-Content -LiteralPath (Join-Path $root '.AL-Go/settings.json') -Raw | ConvertFrom-Json
$temp = Join-Path ([IO.Path]::GetTempPath()) ('foundation-adapter-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    foreach ($mode in 'Default', 'Test') {
        foreach ($workspace in $false, $true) {
            $settings = $original | ConvertTo-Json -Depth 100 | ConvertFrom-Json
            $settings.appDependencyProbingPaths += [pscustomobject]@{repo='https://github.com/example/unrelated'; release_status='latestBuild'; version='1.2.3.4'; projects='*'}
            $settings | Add-Member installApps @('keep-current-build.app')
            $settings | Add-Member installTestApps @('(keep-test-marker.app)')
            $settings | Add-Member workspaceCompilation ([pscustomobject]@{enabled=$workspace;parallelism=2})
            $raw = $settings | ConvertTo-Json -Depth 100 -Compress
            $filtered = Get-FoundationResolverSettings $raw
            $actual = $filtered | ConvertFrom-Json
            Assert-Adapter ($actual.appDependencyProbingPaths.Count -eq 1 -and $actual.appDependencyProbingPaths[0].repo -ceq 'https://github.com/example/unrelated') 'Unrelated probe changed.'
            $before = $raw | ConvertFrom-Json
            $before.appDependencyProbingPaths = $actual.appDependencyProbingPaths
            Assert-Adapter (($before | ConvertTo-Json -Depth 100 -Compress) -ceq $filtered) 'Non-probe effective Settings changed.'
            $stock = @{}
            foreach ($property in $actual.PSObject.Properties) { $stock[$property.Name]=$property.Value }
            $stock.applicationDependency='28.0.0.0'; $stock.type='PTE'
            $stock.appFolders=@(); $stock.testFolders=@(); $stock.bcptTestFolders=@()
            $stock.appDependencies=@(); $stock.testDependencies=@(); $stock.projectsToTest=@()
            $stock.doNotRunTests=$true; $stock.doNotRunBcptTests=$true; $stock.doNotBuildTests=$true
            $stockRaw = $stock | ConvertTo-Json -Depth 100 -Compress
            $afterAnalyze = AnalyzeRepo -settings $stock -baseFolder $temp -project '.' -doNotCheckArtifactSetting -doNotIssueWarnings
            $afterCheck = CheckAppDependencyProbingPaths -settings $afterAnalyze -baseFolder $temp -token 'fixture-public-token'
            Assert-Adapter ($afterCheck.appDependencyProbingPaths.Count -eq 1 -and $afterCheck.appDependencyProbingPaths[0].repo -ceq 'https://github.com/example/unrelated') 'Stock AnalyzeRepo reintroduced Foundation.'
            Assert-Adapter ($afterCheck.installApps[0] -ceq 'keep-current-build.app' -and $afterCheck.installTestApps[0] -ceq '(keep-test-marker.app)' -and $afterCheck.workspaceCompilation.enabled -eq $workspace) 'Stock settings lost consumers/markers.'
            $env:Settings = $stockRaw
            $resolved = @(DownloadDependenciesFromProbingPaths -baseFolder $temp -project '.' -destinationPath $temp -token 'fixture-public-token')
            Assert-Adapter ($script:observedProbes.Count -eq 1 -and $script:observedProbes[0].repo -ceq 'https://github.com/example/unrelated' -and $resolved[0] -ceq 'unrelated-resolved.app') 'Stock resolver probed Foundation or lost unrelated dependencies.'

        }
    }
    foreach ($mutation in 'missing', 'multiple', 'version', 'extra') {
        $settings = $original | ConvertTo-Json -Depth 100 | ConvertFrom-Json
        switch ($mutation) {
            missing { $settings.appDependencyProbingPaths=@() }
            multiple { $settings.appDependencyProbingPaths+= $settings.appDependencyProbingPaths[0] }
            version { $settings.appDependencyProbingPaths[0].version='latest' }
            extra { $settings.appDependencyProbingPaths[0] | Add-Member extra 'unsupported' }
        }
        Assert-Refusal { Get-FoundationResolverSettings ($settings | ConvertTo-Json -Depth 100) }
    }
    $script:metadataMutation='none'
    $script:zipMutation=$false
    function Invoke-FoundationRequest {
        param([uri] $Uri, [string] $Token, [string] $OutFile, [datetime] $Deadline)
        if ($Uri.AbsolutePath -like '*/runs/*') {
            $meta = Get-Content -LiteralPath (Join-Path $MetadataFolder 'foundation-run.json') -Raw | ConvertFrom-Json
            switch ($script:metadataMutation) {
                run { $meta.id=1 }
                source { $meta.head_sha='0'*40 }
                attempt { $meta.run_attempt=2 }
                status { $meta.status='in_progress' }
                conclusion { $meta.conclusion='failure' }
            }
            return $meta
        }
        $id = if ($Uri.AbsolutePath -match '/artifacts/(\d+)') { $Matches[1] } else { throw 'Unexpected API fixture path.' }
        if ($OutFile) {
            Copy-Item -LiteralPath (Join-Path $CandidateArtifactFolder "foundation530-$id.zip") -Destination $OutFile
            if ($script:zipMutation) { [IO.File]::AppendAllText($OutFile, 'changed') }
            return
        }
        $name = if ($id -eq '11508979803') { 'foundation-apps-artifact.json' } else { 'foundation-testapps-artifact.json' }
        $meta = Get-Content -LiteralPath (Join-Path $MetadataFolder $name) -Raw | ConvertFrom-Json
        switch ($script:metadataMutation) {
            id { $meta.id=1 }
            expiry { $meta.expired=$true }
            expiresAt { $meta.expires_at='2020-01-01T00:00:00Z' }
            digest { $meta.digest='sha256:' + ('0'*64) }
            artifactSource { $meta.workflow_run.head_sha='0'*40 }
            artifactRun { $meta.workflow_run.id=1 }
            size { $meta.size_in_bytes=134217729 }
            name { $meta.name='unapproved-artifact' }
            downloadFailure { throw 'bounded mocked download failure' }
        }
        return $meta
    }
    $dest = Join-Path $temp 'success'
    $manifestPath = Save-FoundationArchives -Token 'mock-token' -Destination $dest
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Assert-Adapter ($manifest.artifacts.Apps.archive -ne $manifest.artifacts.TestApps.archive) 'Archives share a retained path.'
    Assert-Adapter ((Get-FileHash $manifest.artifacts.Apps.archive).Hash.ToLowerInvariant() -ceq $manifest.artifacts.Apps.provenance.archiveSha256) 'Genuine Apps hash changed.'
    Assert-Adapter ((Get-FileHash $manifest.artifacts.TestApps.archive).Hash.ToLowerInvariant() -ceq $manifest.artifacts.TestApps.provenance.archiveSha256) 'Genuine TestApps hash changed.'
    Assert-Refusal { Save-FoundationArchives -Token 'mock-token' -Destination $dest }
    foreach ($mutation in 'run','source','attempt','status','conclusion','id','expiry','expiresAt','digest','artifactSource','artifactRun','size','name','downloadFailure') {
        $script:metadataMutation=$mutation
        $dest = Join-Path $temp $mutation
        Assert-Refusal { Save-FoundationArchives -Token 'mock-token' -Destination $dest }
        Assert-Adapter (-not (Test-Path -LiteralPath $dest)) 'Failed acquisition retained emitted inputs.'
    }
    $script:metadataMutation='none'; $script:zipMutation=$true
    $dest=Join-Path $temp 'changedZip'
    Assert-Refusal { Save-FoundationArchives -Token 'mock-token' -Destination $dest }
    Assert-Adapter (-not (Test-Path -LiteralPath $dest)) 'Changed archive emitted.'
    Write-Host "Foundation resolver/acquisition: $count assertions passed; network/runner/AL not certified."
}
finally { $env:Settings=$savedSettings; Remove-Item -LiteralPath $temp -Recurse -Force }
