# Bifrost: never ship the test app's internalsVisibleTo grant.
# COSMO Alpaca replaces .AL-Go/PreCompileApp.ps1 with its own override and never calls ours,
# so the strip happens here, before anything compiles. Only the Test build mode keeps the grant.
# The original pipeline contract retains the early strip. Write only on a real
# change so an already prepared workspace manifest keeps its receipt hash.
if ($env:BuildMode -ne 'Test') {
    $appJsonPath = Join-Path $env:GITHUB_WORKSPACE 'app/app.json'
    $appJson = Get-Content -LiteralPath $appJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $changed = $false
    if ($appJson.PSObject.Properties.Name -contains 'internalsVisibleTo') {
        $appJson.PSObject.Properties.Remove('internalsVisibleTo')
        $changed = $true
    }
    if ($appJson.PSObject.Properties['suppressWarnings'] -and 'AS0081' -in $appJson.suppressWarnings) {
        $appJson.suppressWarnings = @($appJson.suppressWarnings | Where-Object { $_ -ne 'AS0081' })
        $changed = $true
    }
    if ($changed) { $appJson | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $appJsonPath -Encoding UTF8 }
}

& (Join-Path $env:GITHUB_WORKSPACE 'tools/Prepare-FoundationInputs.ps1') -Action PrepareManifest

Write-Host "::group::PipelineInitialize"

if (Test-Path -LiteralPath "$($env:NeedsContext)" -PathType Leaf) {
    Write-Host "Load Context from file at '$($env:NeedsContext)'"
    $needsContext = "$($env:NeedsContext)" | Get-Item | Get-Content -Raw | ConvertFrom-Json
}
else {
    Write-Host "Load Context from Json"
    $needsContext = "$($env:NeedsContext)" | ConvertFrom-Json
}

$initializationJob = $needsContext.'CustomJob-Alpaca-Initialization'

$scriptsPath = "./.alpaca/Scripts/"
$scriptsArchiveUrl = $initializationJob.outputs.scriptsArchiveUrl
$scriptsArchiveDirectory = $initializationJob.outputs.scriptsArchiveDirectory

Write-Host "Collect workflow jobs from context:"
$jobs = @{}
$jobIds = $initializationJob.outputs.jobIdsJson | ConvertFrom-Json
foreach ($jobId in $jobIds.PSObject.Properties.GetEnumerator()) {
    if ($needsContext.PSObject.Properties.Name -contains $jobId.Value) {
        Write-Host " - $($jobId.Name): $($jobId.Value)"
        $jobs[$jobId.Name] = $needsContext.$($jobId.Value)
    }
}
if ($jobs.Count -eq 0) {
    Write-Host " - None"
}

Write-Host "Prepare Alpaca scripts directory at '$scriptsPath'"
if (Test-Path -Path $scriptsPath) {
    Remove-Item -Path $scriptsPath -Recurse -Force
}
New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null

if ($scriptsArchiveUrl) {
    try {
        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        $tempArchivePath = "$tempPath.zip"

        Write-Host "Download Alpaca scripts archive from '$scriptsArchiveUrl'"
        Invoke-WebRequest -Uri $scriptsArchiveUrl -OutFile $tempArchivePath
        $script:AppSourceAlpacaArchiveHash = (Get-FileHash -LiteralPath $tempArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()

        Write-Host "Extract Alpaca scripts archive"
        Expand-Archive -Path $tempArchivePath -DestinationPath $tempPath -Force

        Write-Host "Copy Alpaca scripts to '$scriptsPath'"
        Get-Item -Path (Join-Path $tempPath $scriptsArchiveDirectory) |
            Get-ChildItem |
            ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $scriptsPath -Recurse -Force
            }
    }
    catch {
        throw
    }
    finally {
        if ($tempPath -and (Test-Path $tempPath)) {
            Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        if ($tempArchivePath -and (Test-Path $tempArchivePath)) {
            Remove-Item -Path $tempArchivePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "Alpaca scripts found:"
$scriptFiles = Get-ChildItem -Path $scriptsPath -File -Recurse
if ($scriptFiles) {
    $scriptFiles | ForEach-Object {
        Write-Host "- $(Resolve-Path -Path $_.FullName -Relative)"
    }
} else {
    Write-Host "- None"
}

# Revalidate selected publication inputs before invoking downloaded Alpaca scans.
& (Join-Path $env:GITHUB_WORKSPACE 'tools/Prepare-FoundationInputs.ps1') -Action Validate

$overridesPath = Join-Path $scriptsPath "/Overrides/RunAlPipeline"
Write-Host "Alpaca overrides path: $overridesPath"
$overridePath = Join-Path $overridesPath "PipelineInitialize.ps1"
if (Test-Path $overridePath) {
    if ($env:BIFROST_SHARED_CONTAINER -eq 'true') {
        . ./tools/SharedAlpacaContainer.ps1
        Initialize-BifrostSharedContainer -OverridePath $overridePath -ScriptsPath $scriptsPath -BackendUrl $jobs.initialization.outputs.backendUrl
    }
    Write-Host "Invoking Alpaca override"
    . $overridePath -Jobs $jobs -ScriptsPath $scriptsPath
}

if ($env:BIFROST_SHARED_CONTAINER -eq 'true') {
    if ($env:ALPACA_CONTAINER_ID -ne $env:BIFROST_CONTAINER_ID) { throw 'Alpaca selected a different container.' }
    Set-Variable -Name 'BifrostAlpacaPublish' -Value (Get-Variable -Name 'PublishBcContainerApp' -Scope 1 -ValueOnly) -Scope 1
    Set-Variable -Name 'PublishBcContainerApp' -Scope 1 -Value {
        param([hashtable] $Parameters)
        . ./tools/SharedAlpacaContainer.ps1
        Invoke-BifrostSharedPublish -Parameters $Parameters -Publisher $BifrostAlpacaPublish
    }
}


Write-Host "::endgroup::"

# Preserve the existing stripping/Alpaca override; initialize current-run evidence
# after the downloaded overrides are installed, before any final app compile.
& (Join-Path $env:GITHUB_WORKSPACE 'tools/Assert-AppSourceBuild.ps1') -Stage Initialize -AlpacaArchiveHash $script:AppSourceAlpacaArchiveHash

# AL-Go v9.2 does NOT include CompileAppWithBcCompilerFolder in its automatic
# override registry. Install Run-AlPipeline's real callback using the same
# parent-context scope mechanism as the downloaded Alpaca initialization.
# Do not displace an existing owner's compiler override.
function Set-AppSourceWorkspaceRefusal {
    $existing = Get-Variable -Name 'CompileAppWithBcCompilerFolder' -Scope 2 -ValueOnly -ErrorAction Stop
    if ($existing) { throw 'Existing workspace compiler override requires owner coordination.' }
    Set-Variable -Name 'CompileAppWithBcCompilerFolder' -Scope 2 -Value {
        param([hashtable] $CompilationParams)
        throw 'Unexpected recompilation on prebuilt workspace backend.'
    }
}

# Prebuilt workspace packages must never enter a classic compiling callback.
if (($env:Settings | ConvertFrom-Json).workspaceCompilation.enabled) {
    Set-AppSourceWorkspaceRefusal
    return
}

function Set-AppSourceCompilerCallback {
    $existing = Get-Variable -Name 'CompileAppWithBcCompilerFolder' -Scope 2 -ValueOnly -ErrorAction Stop
    if ($existing) {
        throw 'Existing compiler-folder override requires owner coordination; refusing to replace it.'
    }
    $callback = (Get-Command (Join-Path $env:GITHUB_WORKSPACE '.AL-Go/CompileAppWithBcCompilerFolder.ps1')).ScriptBlock
    Set-Variable -Name 'CompileAppWithBcCompilerFolder' -Value $callback -Scope 2
}
Set-AppSourceCompilerCallback
