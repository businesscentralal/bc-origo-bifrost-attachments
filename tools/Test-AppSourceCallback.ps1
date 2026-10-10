<#
.SYNOPSIS
Checks actual callback/collector/native-process return and failure plumbing.
Controlled verifier/compiler fixtures do not certify AL, helper runtime or BC.
#>
param([string] $CandidateArtifactFolder = $env:FOUNDATION_CANDIDATE_ARTIFACTS,
      [string] $WorkspaceModulePath = $env:FOUNDATION_WORKSPACE_MODULE,
      [string] $FixtureFolder = $env:APPSOURCE_GATE_FIXTURES)
$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('attachments78-callback-' + [guid]::NewGuid())
$names = @('GITHUB_WORKSPACE','GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_JOB','GITHUB_SHA','BuildMode','Settings','RUNNER_TEMP','GITHUB_OUTPUT','APPSOURCE_GATE_FIXTURES','FOUNDATION_CANDIDATE_ARTIFACTS','FOUNDATION_WORKSPACE_MODULE','PYTHONDONTWRITEBYTECODE')
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
$count = 0
function Assert-Contract($Condition, $Message) { if (-not $Condition) { throw $Message } }
try {
    New-Item -ItemType Directory -Path (Join-Path $fixture 'tools') -Force | Out-Null
    Push-Location $fixture
    $env:PYTHONDONTWRITEBYTECODE = '1'
    Copy-Item (Join-Path $source 'tools/Assert-AppSourceBuild.ps1') (Join-Path $fixture 'tools/Assert-AppSourceBuild.ps1')
    foreach ($tool in 'Prepare-FoundationInputs.ps1', 'stage_foundation_inputs.py', 'appsource_gate.py') {
        Copy-Item (Join-Path $source "tools/$tool") (Join-Path $fixture "tools/$tool")
    }
    if (-not $CandidateArtifactFolder) { throw 'Missing genuine CandidateArtifactFolder for mandatory preparation fixture.' }
    $realGate = Get-Content (Join-Path $source 'tools/appsource_gate.py') -Raw
    # Keep genuine package/staging definitions importable by the real preparation
    # process. Only the separate gate CLI is controlled for callback-contract tests.
    function Set-FixtureGate([string] $Body) {
        $prefix = $realGate.Substring(0, $realGate.LastIndexOf('if __name__ == "__main__":'))
        [IO.File]::WriteAllText((Join-Path $fixture 'tools/appsource_gate.py'), $prefix + "if __name__ == `"__main__`":`n    pass`n" + (($Body -split "`n" | ForEach-Object { '    ' + $_ }) -join "`n"))
    }
    $env:RUNNER_TEMP = Join-Path $fixture 'runner-temp'
    New-Item -ItemType Directory -Path $env:RUNNER_TEMP | Out-Null
    $env:GITHUB_OUTPUT = Join-Path $fixture 'outputs.txt'
    $env:GITHUB_WORKSPACE = $fixture
    $env:GITHUB_RUN_ID = '1234'; $env:GITHUB_RUN_ATTEMPT = '1'; $env:GITHUB_JOB = 'callback-fixture'; $env:GITHUB_SHA = 'a' * 40
    $env:Settings = @{enableCodeCop=$true;enableUICop=$true;enableCodeAnalyzersOnTestApps=$true;failOn='warning';workspaceCompilation=@{enabled=$false};type='AppSource App'} | ConvertTo-Json
    function global:git { 'a' * 40; $global:LASTEXITCODE = 0 }
    $script:compilerCalls = 0
    $script:throwCompiler = $false
    function global:Compile-AppWithBcCompilerFolder {
        param([scriptblock] $OutputTo, [string] $appProjectFolder, [string] $appSymbolsFolder, [string] $compilerFolder,
              [bool] $CopyAppToSymbolsFolder, [string] $GenerateReportLayout, [bool] $enableCodeCop, [bool] $enableUICop,
              [bool] $enableAppSourceCop, [bool] $enablePerTenantExtensionCop, [string] $failOn)
        $script:compilerCalls++
        $script:forwarded = $PSBoundParameters
        $OutputTo.Invoke('compiler-line-one') | Out-Null
        $OutputTo.Invoke('compiler-line-two') | Out-Null
        if ($script:throwCompiler) { throw 'original-compiler-failure' }
        'original-package.app'
    }
    $callback = (Get-Command (Join-Path $source '.AL-Go/CompileAppWithBcCompilerFolder.ps1')).ScriptBlock
    foreach ($mode in 'Default','Test') {
        $env:BuildMode = $mode
        # Build a genuine pinned acquisition manifest, then execute actual Stage
        # and publication. Missing/changed archives remain failing inputs.
        Copy-Item (Join-Path $source 'tools/appsource_gate.py') (Join-Path $fixture 'tools/appsource_gate.py')
        $manifestBuilder = @'
import sys,json
from pathlib import Path
sys.path.insert(0,sys.argv[1])
import stage_foundation_inputs as S
c=S.PROFILES['candidate530']
artifacts={k:dict(archive=str(Path(sys.argv[2])/f'foundation530-{v[0]}.zip'),provenance=dict(repository='OrigoSoftwareSolutions/bc-origo-bifrost-core',sourceSha=c['source'],run=c['run'],attempt=c['attempt'],artifactId=v[0],archiveSha256=v[1],expired=False,conclusion='success')) for k,v in c['artifacts'].items()}
Path(sys.argv[3]).write_text(json.dumps(dict(profile='candidate530',artifacts=artifacts)))
'@
        $manifestPath = Join-Path $fixture 'archives.json'
        & python3 -c $manifestBuilder (Join-Path $fixture 'tools') $CandidateArtifactFolder $manifestPath
        if ($LASTEXITCODE -ne 0) { throw 'Genuine preparation fixture construction failed.' }
        $emptyArray = Join-Path $fixture 'empty.json'
        [IO.File]::WriteAllText($emptyArray, '[]')
        Remove-Item (Join-Path $fixture '.dependencies') -Recurse -Force -ErrorAction SilentlyContinue
        & (Join-Path $fixture 'tools/Prepare-FoundationInputs.ps1') -Action Stage -ArchiveManifestPath $manifestPath -DownloadedApps $emptyArray -DownloadedTestApps $emptyArray
        $published = Get-ChildItem (Join-Path $fixture '.dependencies') -Filter '*.app' -Recurse -File
        Assert-Contract ($published.Count -eq 1) 'Missing selected genuine Foundation fixture'
        Copy-Item $published.FullName $fixture -Force
        New-Item -ItemType Directory -Path (Join-Path $fixture 'symbols') -Force | Out-Null
        Copy-Item $published.FullName (Join-Path $fixture 'symbols') -Force
        $directory = Join-Path $fixture ".buildartifacts/AppSourceGate/$mode"
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        @{context=@{run='1234';attempt='1';sourceCommit=('a'*40);checkoutSha=('a'*40);mode=$mode};receipts=@{}} | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $directory 'state.json')
        foreach ($translation in $true,$false) {
            # Actual native Python process, exact CLI success text; no package verdict.
            Set-FixtureGate "print('AppSource gate: before passed')"
            $script:received = @()
            $sink = {param($Line) $script:received += $Line; 'sink-output-must-not-return'}
            $parameters = @{OutputTo=$sink;appProjectFolder=$fixture;appSymbolsFolder=$fixture;compilerFolder=$fixture;
                CopyAppToSymbolsFolder=(-not $translation);GenerateReportLayout=$(if ($translation) {'No'} else {'Yes'});
                enableCodeCop=(-not $translation);enableUICop=(-not $translation);enableAppSourceCop=(-not $translation);
                enablePerTenantExtensionCop=$false;failOn='warning'}
            $returned = @(Invoke-Command -ScriptBlock $callback -ArgumentList $parameters)
            Assert-Contract ($returned.Count -eq 1 -and $returned[0] -ceq 'original-package.app') 'Callback polluted original package return'
            Assert-Contract ($parameters.OutputTo -eq $sink -and $script:forwarded.OutputTo -ne $sink) 'Original parameters mutated or output not wrapped'
            foreach ($key in $parameters.Keys) {
                if ($key -ne 'OutputTo') { Assert-Contract ($script:forwarded[$key] -eq $parameters[$key]) "Parameter forwarding changed: $key" }
            }
            Assert-Contract (($script:received -join '|') -ceq 'compiler-line-one|compiler-line-two') 'Original sink lost output'
            Assert-Contract (([IO.File]::ReadAllLines((Join-Path $directory 'current-compile.txt')) -join '|') -ceq 'compiler-line-one|compiler-line-two') 'Isolated log differs'
            $count++
            foreach ($silentOrInvalid in @(
                '# Truncated gate module: definitions only, no entry point.',
                "print('AppSource gate: post passed')",
                "print('AppSource gate: before passed')`nprint('unexpected extra output')",
                "print('appsource gate: before passed')"
            )) {
                Set-FixtureGate $silentOrInvalid
                $callsBefore = $script:compilerCalls
                $refused = $false
                try { Invoke-Command -ScriptBlock $callback -ArgumentList $parameters | Out-Null }
                catch { $refused = $_.Exception.Message -ceq 'AppSource before validation did not return the expected completion marker.' }
                Assert-Contract ($refused -and $script:compilerCalls -eq $callsBefore) 'Zero-exit verifier without exact completion marker reached compiler'
                Assert-Contract (-not (Test-Path (Join-Path $fixture '.buildartifacts/AppSourceGate/request.json'))) 'Invalid-marker request cleanup failed'
                $count++
            }
            Set-FixtureGate "print('AppSource gate: before passed')"
            $script:throwCompiler = $true
            $preserved = $false
            try { Invoke-Command -ScriptBlock $callback -ArgumentList $parameters | Out-Null } catch { $preserved = $_.Exception.Message -ceq 'original-compiler-failure' }
            Assert-Contract $preserved 'Original compiler exception replaced/suppressed'
            $script:throwCompiler = $false
            $count++
            Set-FixtureGate "import sys`nprint('native-refusal', file=sys.stderr)`nsys.exit(7)"
            $callsBefore = $script:compilerCalls
            $refused = $false
            try { Invoke-Command -ScriptBlock $callback -ArgumentList $parameters | Out-Null } catch { $refused = $_.Exception.Message -ceq 'AppSource before validation failed.' }
            Assert-Contract ($refused -and $script:compilerCalls -eq $callsBefore) 'Native verifier failure did not refuse before compiler'
            Assert-Contract (-not (Test-Path (Join-Path $fixture '.buildartifacts/AppSourceGate/request.json'))) 'Native request cleanup failed'
            $count++
        }
    }
    New-Item -ItemType Directory -Path (Join-Path $fixture '.AL-Go') -Force | Out-Null
    Copy-Item (Join-Path $source '.AL-Go/CompileAppWithBcCompilerFolder.ps1') (Join-Path $fixture '.AL-Go/CompileAppWithBcCompilerFolder.ps1')
    Set-FixtureGate "print('AppSource gate: before passed')"
    $initialize = Get-Content (Join-Path $source '.AL-Go/PipelineInitialize.ps1') -Raw
    $installer = [scriptblock]::Create($initialize.Substring($initialize.IndexOf('function Set-AppSourceCompilerCallback')))
    $module = New-Module -Name AppSourceCallbackFixture -ScriptBlock {
        function Invoke-HelperFixture {
            param([scriptblock] $PipelineInitialize, [scriptblock] $CompileAppWithBcCompilerFolder)
            Invoke-Command -ScriptBlock $PipelineInitialize
            if (-not $CompileAppWithBcCompilerFolder) { throw 'Callback not installed in helper scope' }
            $folder = $env:GITHUB_WORKSPACE
            $buildOutputFile = Join-Path $folder 'BuildOutput.txt'
            $output = {param($line)
                Write-Host $line
                if ($line -like "$($folder)*") { Add-Content $buildOutputFile $line.SubString($folder.Length+1) }
                else { Add-Content $buildOutputFile $line }
            }
            $parameters = @{OutputTo=$output;appProjectFolder=$folder;appSymbolsFolder=$folder;compilerFolder=$folder;CopyAppToSymbolsFolder=$true}
            Invoke-Command -ScriptBlock $CompileAppWithBcCompilerFolder -ArgumentList $parameters
        }
        Export-ModuleMember -Function Invoke-HelperFixture
    }
    Import-Module $module
    $returned = @(Invoke-HelperFixture -PipelineInitialize $installer)
    Assert-Contract ($returned.Count -eq 1 -and $returned[0] -ceq 'original-package.app') 'Module callback return changed'
    Assert-Contract (([IO.File]::ReadAllLines((Join-Path $fixture 'BuildOutput.txt')) -join '|') -ceq 'compiler-line-one|compiler-line-two') 'Helper dynamic output sink lost scope'
    $count++
    $refused = $false
    try { Invoke-HelperFixture -PipelineInitialize $installer -CompileAppWithBcCompilerFolder {'foreign.app'} | Out-Null }
    catch { $refused = $_.Exception.Message -like 'Existing compiler-folder override*' }
    Assert-Contract $refused 'Existing owner callback displaced'
    $count++
    # Invoke the genuine pinned function, with controlled filesystem/compiler
    # ancillaries only. Both repository hooks run at actual positional call sites.
    if (-not $WorkspaceModulePath -or -not (Test-Path -LiteralPath $WorkspaceModulePath)) { throw 'Missing genuine WorkspaceModulePath.' }
    if ((Get-FileHash -LiteralPath $WorkspaceModulePath).Hash.ToLowerInvariant() -cne 'fcf82a3a83f6925c26adcd0876d57f59ba3c29ad8b2e9a1c11c70eaa9aefb73e') { throw 'Unpinned workspace function source.' }
    Import-Module $WorkspaceModulePath -Force
    $workspaceModule = Get-Module CompileFromWorkspace
    & $workspaceModule {
        function script:Get-ALTool { param($CompilerFolder) 'controlled-altool' }
        function script:New-WorkspaceFromFolders {
            param($Folders,$WorkspaceFile,$ALToolPath)
            @{folders=@($Folders | ForEach-Object { @{path=$_} })} | ConvertTo-Json -Depth 10 | Set-Content $WorkspaceFile
        }
        function script:CompileAppsInWorkspace {
            param($ALToolPath,$WorkspaceFile,$PackageCachePath,$OutFolder,$LogDirectory,$ErrorLogDirectory,$AssemblyProbingPaths,$Analyzers,$CustomAnalyzers,$PreprocessorSymbols,$Features,$GenerateReportLayout,$Ruleset,$SourceRepositoryUrl,$SourceCommit,$ReportSuppressedDiagnostics,$EnableExternalRulesets,$MaxCpuCount)
            $global:workspaceCompilerCalls++
            $global:workspaceActual = $PSBoundParameters
            if ($global:workspaceCompilerFailure) { throw 'original-workspace-compiler-failure' }
            'workspace-one.app'; 'workspace-two.app'
        }
    }
    Copy-Item (Join-Path $source '.AL-Go/PreCompileApp.ps1') (Join-Path $fixture '.AL-Go/PreCompileApp.ps1')
    Copy-Item (Join-Path $source '.AL-Go/PostCompileApp.ps1') (Join-Path $fixture '.AL-Go/PostCompileApp.ps1')
    # This controlled collector checks the hook transport only. Python tests
    # separately execute the real strict workspace collector on genuine packages.
    @'
param($Stage,$AppType,$CompilationParams,[string[]]$AppFile)
if ($global:workspaceHookFailure -eq $Stage) { throw 'original-workspace-hook-failure' }
if ($AppType -cnotin @('app','testApp')) { throw 'unexpected-workspace-AppType' }
if (-not $CompilationParams.WorkspaceFile -or -not $CompilationParams.PackageCachePath -or -not $CompilationParams.OutFolder -or -not $CompilationParams.ALToolPath) { throw 'missing-genuine-workspace-parameters' }
if ($Stage -eq 'WorkspaceBefore') { $global:workspacePreReceipt = $CompilationParams.Clone() }
elseif ($Stage -eq 'WorkspacePost') {
    if (($AppFile -join '|') -cne 'workspace-one.app|workspace-two.app') { throw 'workspace-output-array-lost' }
    $global:workspacePostReceipt = $CompilationParams.Clone()
}
else { throw 'wrong-workspace-stage' }
'@ | Set-Content (Join-Path $fixture 'tools/Assert-AppSourceBuild.ps1')
    $nativePreHook = (Get-Command (Join-Path $fixture '.AL-Go/PreCompileApp.ps1')).ScriptBlock
    $nativePostHook = (Get-Command (Join-Path $fixture '.AL-Go/PostCompileApp.ps1')).ScriptBlock
    $global:workspaceCompilerCalls = 0; $global:workspaceCompilerFailure = $false; $global:workspaceHookFailure = ''
    foreach ($mode in 'Default','Test') {
        $env:BuildMode = $mode
        foreach ($appType in $(if ($mode -eq 'Test') { @('app','testApp') } else { @('app') })) {
            $arguments = @{Folders=@($fixture);CompilerFolder=$fixture;PackageCachePath=$fixture;OutFolder=$fixture;AppType=$appType;
                          PreCompileApp=$nativePreHook;PostCompileApp=$nativePostHook;Analyzers=@('CodeCop','UICop','AppSourceCop');
                          Features=@('TranslationFile');SourceCommit=('a'*40);GenerateReportLayout=$true}
            $returned = @(Build-AppsInWorkspace @arguments)
            Assert-Contract (($returned -join '|') -ceq 'workspace-one.app|workspace-two.app') 'Workspace hook polluted compiler output'
            foreach ($key in $global:workspacePreReceipt.Keys) {
                Assert-Contract (($global:workspacePreReceipt[$key] | ConvertTo-Json -Depth 10 -Compress) -ceq ($global:workspacePostReceipt[$key] | ConvertTo-Json -Depth 10 -Compress)) "Workspace parameter changed: $key"
            }
            $count++
            foreach ($failure in 'WorkspaceBefore','WorkspacePost') {
                $global:workspaceHookFailure = $failure
                $callsBefore = $global:workspaceCompilerCalls
                $refused = $false
                try { Build-AppsInWorkspace @arguments | Out-Null } catch { $refused = $_.Exception.Message -ceq 'original-workspace-hook-failure' }
                Assert-Contract $refused 'Workspace original hook error changed'
                Assert-Contract ($global:workspaceCompilerCalls -eq ($callsBefore + $(if ($failure -eq 'WorkspaceBefore') {0} else {1}))) 'Workspace compiler call order changed on hook failure'
                $count++
            }
            $global:workspaceHookFailure = ''; $global:workspaceCompilerFailure = $true
            $refused = $false
            try { Build-AppsInWorkspace @arguments | Out-Null } catch { $refused = $_.Exception.Message -ceq 'original-workspace-compiler-failure' }
            Assert-Contract $refused 'Workspace original compiler error changed'
            $global:workspaceCompilerFailure = $false; $count++
            $arguments.PreCompileApp = { param($AppType,[ref]$Parameters)
                & (Join-Path $env:GITHUB_WORKSPACE '.AL-Go/PreCompileApp.ps1') $AppType $Parameters
                $Parameters.Value.Features = @('ref-contract-probe')
            }
            $returned = @(Build-AppsInWorkspace @arguments)
            Assert-Contract ($global:workspaceActual.Features[0] -ceq 'ref-contract-probe' -and $global:workspacePostReceipt.Features[0] -ceq 'ref-contract-probe') 'Genuine workspace ref contract not forwarded'
            $count++
        }
    }
    foreach ($appType in '','bcptApp','unexpected') {
        $refused = $false
        try { Build-AppsInWorkspace -Folders @($fixture) -CompilerFolder $fixture -AppType $appType -PreCompileApp $nativePreHook -PostCompileApp $nativePostHook | Out-Null } catch { $refused = $true }
        Assert-Contract $refused 'Empty/unknown workspace AppType accepted'
        $count++
    }
    # Early preparation is deterministic, preserves unrelated properties and Test
    # friendship, and precedes genuine workspace creation in workflow source.
    New-Item -ItemType Directory -Path (Join-Path $fixture 'app') -Force | Out-Null
    $manifestPath = Join-Path $fixture 'app/app.json'
    $manifest = @{id='fixture';name='fixture';internalsVisibleTo=@(@{id='approved-test'});features=@('TranslationFile');dependencies=@(@{id='dependency'})}
    $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath
    $env:BuildMode = 'Test'
    $original = [IO.File]::ReadAllBytes($manifestPath)
    & (Join-Path $fixture 'tools/Prepare-FoundationInputs.ps1') -Action PrepareManifest
    Assert-Contract ([Convert]::ToBase64String($original) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($manifestPath))) 'Test manifest bytes changed'
    $env:BuildMode = 'Default'
    & (Join-Path $fixture 'tools/Prepare-FoundationInputs.ps1') -Action PrepareManifest
    $prepared = Get-Content $manifestPath -Raw | ConvertFrom-Json
    Assert-Contract (-not $prepared.PSObject.Properties['internalsVisibleTo'] -and $prepared.features[0] -ceq 'TranslationFile' -and $prepared.dependencies[0].id -ceq 'dependency') 'Early removal altered unrelated manifest properties'
    $firstHash = (Get-FileHash $manifestPath).Hash
    & (Join-Path $fixture 'tools/Prepare-FoundationInputs.ps1') -Action PrepareManifest
    Assert-Contract ($firstHash -ceq (Get-FileHash $manifestPath).Hash) 'Early manifest preparation not idempotent'
    $count += 3
    if (-not $FixtureFolder -or -not (Test-Path -LiteralPath $FixtureFolder)) { throw 'Missing genuine FixtureFolder for strict workspace collector tests.' }
    $env:APPSOURCE_GATE_FIXTURES = (Resolve-Path -LiteralPath $FixtureFolder).Path
    $env:FOUNDATION_CANDIDATE_ARTIFACTS = (Resolve-Path -LiteralPath $CandidateArtifactFolder).Path
    $env:FOUNDATION_WORKSPACE_MODULE = (Resolve-Path -LiteralPath $WorkspaceModulePath).Path
    & python3 -m unittest discover -s (Join-Path $source 'tools/tests') -p 'test_appsource_workspace.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'Strict workspace collector regressions failed.' }
    Write-Host "Callback regressions: $count passed, 0 failed; actual PowerShell callback/collector and native Python, controlled compiler/verifier. No AL/runtime certification."
} finally {
    Pop-Location
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    Remove-Item Function:\git, Function:\Compile-AppWithBcCompilerFolder -ErrorAction SilentlyContinue
    Remove-Module CompileFromWorkspace -ErrorAction SilentlyContinue
    Remove-Module AppSourceCallbackFixture -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
