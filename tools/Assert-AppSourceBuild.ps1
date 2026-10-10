param(
    [ValidateSet('Initialize', 'BeforeCompile', 'PostCompile', 'Finalize', 'Pipeline', 'Signed', 'WorkspaceBefore', 'WorkspacePost', 'WorkspaceInitialize')]
    [string] $Stage,
    [string] $Root = $env:GITHUB_WORKSPACE,
    [string[]] $AppFile,
    [string] $AppType,
    [hashtable] $CompilationParams,
    [string] $AlpacaArchiveHash
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-FileReceipt {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw 'Required compiler/analyzer/helper input is absent.'
    }
    $file = Get-Item -LiteralPath $Path
    return @{ sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant(); version = $file.VersionInfo.FileVersion }
}

function Get-Context {
    foreach ($name in 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'GITHUB_JOB', 'GITHUB_SHA', 'BuildMode') {
        if (-not [Environment]::GetEnvironmentVariable($name)) {
            throw "Missing actual pipeline identity: $name"
        }
    }
    $checkoutSha = & git -C $Root rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $checkoutSha -notmatch '^[a-f0-9]{40}$') {
        throw 'Actual checkout SHA unavailable.'
    }
    return @{
        run = $env:GITHUB_RUN_ID
        attempt = $env:GITHUB_RUN_ATTEMPT
        job = $env:GITHUB_JOB
        sourceCommit = $env:GITHUB_SHA
        checkoutSha = $checkoutSha
        mode = $env:BuildMode
        project = '.'
        buildUrl = "$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"
    }
}

function Read-Settings {
    if (-not $env:Settings) {
        throw 'Actual merged AL-Go settings missing.'
    }
    return $env:Settings | ConvertFrom-Json
}

function Get-Setting {
    param($Settings, [string] $Name)
    $property = $Settings.PSObject.Properties[$Name]
    if ($null -eq $property) {
        throw "Required effective setting missing: $Name"
    }
    return $property.Value
}

function Invoke-Gate {
    param([string] $Action, $Request)
    $python = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $python) {
        $python = Get-Command python -ErrorAction Stop
    }
    $path = Join-Path $Root '.buildartifacts/AppSourceGate/request.json'
    $Request | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path -Encoding UTF8
    try {
        # Native success diagnostics must not join the helper's package-return stream.
        $diagnostics = @(& $python.Source (Join-Path $Root 'tools/appsource_gate.py') $Action --root $Root --input $path)
        $gateExitCode = $LASTEXITCODE
        $diagnostics | ForEach-Object { Write-Host $_ }
        if ($gateExitCode -ne 0) {
            throw "AppSource $Action validation failed."
        }
        # A truncated script without main() exits zero without validating anything.
        if ($diagnostics.Count -ne 1 -or $diagnostics[0] -cne "AppSource gate: $Action passed") {
            throw "AppSource $Action validation did not return the expected completion marker."
        }
    }
    finally {
        Remove-Item -LiteralPath $path -Force
    }
}

function Get-WorkspaceSettings {
    param($Settings)
    $effective = @{}
    foreach ($name in 'enableCodeCop', 'enableUICop', 'enableAppSourceCop', 'enableCodeAnalyzersOnTestApps', 'failOn', 'workspaceCompilation', 'type', 'escapeFromCops', 'rulesetFile') {
        $property = $Settings.PSObject.Properties[$name]
        $effective[$name] = if ($property) { $property.Value } else { $null }
    }
    return $effective
}

if ($Stage -eq 'WorkspaceInitialize') {
    $directory = Join-Path $Root '.buildartifacts/AppSourceGate'
    New-Item -Path $directory -ItemType Directory -Force | Out-Null
    Invoke-Gate 'workspace-initialize' @{context=(Get-Context); settings=(Get-WorkspaceSettings (Read-Settings)); selection=(Join-Path $env:RUNNER_TEMP "foundation-selected-$env:GITHUB_RUN_ID-$env:GITHUB_RUN_ATTEMPT-$env:BuildMode/selection.json")}
    return
}

# Separate actual workspace contracts. No classic-parameter impersonation and no
# compiler parameter mutation; caller's ref and returned app stream remain intact.
if ($Stage -in @('WorkspaceBefore', 'WorkspacePost', 'WorkspaceInitialize')) {
    $context = Get-Context
    if (-not $CompilationParams -or $AppType -cnotin @('app', 'testApp')) { throw 'Missing/unexpected workspace contract.' }
    $settings = Read-Settings
    $effective = Get-WorkspaceSettings $settings
    $parameters = @{}
    foreach ($key in $CompilationParams.Keys) {
        $value = $CompilationParams[$key]
        $parameters[$key] = if ($value -is [System.Management.Automation.SwitchParameter]) { $value.IsPresent } else { $value }
    }
    $altool = [string]$parameters.ALToolPath
    $bin = Split-Path $altool -Parent
    $platformBin = $bin
    if ((Split-Path $bin -Leaf) -in @('linux', 'win32', 'darwin')) { $bin = Split-Path $bin -Parent }
    $extension = Split-Path $bin -Parent
    $compiler = Join-Path $platformBin 'alc.exe'
    if (-not (Test-Path -LiteralPath $compiler)) { $compiler = Join-Path $platformBin 'alc' }
    if (-not (Test-Path -LiteralPath $compiler)) { $compiler = Join-Path $bin 'alc.dll' }
    $package = Join-Path $extension 'package.json'
    $packageData = Get-Content -LiteralPath $package -Raw -Encoding UTF8 | ConvertFrom-Json
    $compilerReceipt = Get-FileReceipt $compiler
    if (-not $compilerReceipt.version) { throw 'Workspace compiler executable file version absent.' }
    $tools = @{}
    foreach ($entry in @{compiler=$compiler; altool=$altool; compilerPackage=$package}.GetEnumerator()) {
        $receipt = Get-FileReceipt $entry.Value
        $receipt.path = $entry.Value
        $tools[$entry.Key] = $receipt
    }
    $tools.compilerPackage.version = $packageData.version
    $analyzers = Join-Path $bin 'Analyzers'
    if (-not (Test-Path -LiteralPath $analyzers)) { $analyzers = $bin }
    foreach ($name in 'CodeCop', 'UICop', 'AppSourceCop', 'Analyzers.Common') {
        $path = Join-Path $analyzers "Microsoft.Dynamics.Nav.$name.dll"
        $tools[$name] = Get-FileReceipt $path
        $tools[$name].path = $path
    }
    $module = Get-Command Build-AppsInWorkspace -ErrorAction Stop
    $tools.workspaceModule = Get-FileReceipt $module.ScriptBlock.File
    $tools.workspaceModule.path = $module.ScriptBlock.File
    $moduleFolder = Split-Path $module.ScriptBlock.File -Parent
    foreach ($entry in @{'TelemetryHelper.psm1'='../TelemetryHelper.psm1'; 'Github-Helper.psm1'='../Github-Helper.psm1'; 'AL-Go-Helper.ps1'='../AL-Go-Helper.ps1'; 'DebugLogHelper.psm1'='./DebugLogHelper.psm1'}.GetEnumerator()) {
        $path = (Resolve-Path -LiteralPath (Join-Path $moduleFolder $entry.Value)).Path
        $tools[$entry.Key] = Get-FileReceipt $path
        $tools[$entry.Key].path = $path
    }
    if ($Stage -eq 'WorkspaceBefore') {
        & (Join-Path $Root 'tools/Prepare-FoundationInputs.ps1') -Action Validate -Root $Root
    }
    $directory = Join-Path $Root '.buildartifacts/AppSourceGate'
    New-Item -Path $directory -ItemType Directory -Force | Out-Null
    $action = if ($Stage -eq 'WorkspaceBefore') { 'workspace-before' } else { 'workspace-post' }
    Invoke-Gate $action @{ context=$context; appType=$AppType; appFiles=@($AppFile); selection=(Join-Path $env:RUNNER_TEMP "foundation-selected-$env:GITHUB_RUN_ID-$env:GITHUB_RUN_ATTEMPT-$env:BuildMode/selection.json"); parameters=$parameters; settings=$effective; tools=$tools }
    return
}

$context = Get-Context
$directory = Join-Path $Root ".buildartifacts/AppSourceGate/$($context.mode)"
$settings = Read-Settings
$workspaceBackend = (Get-Setting $settings 'workspaceCompilation').enabled
if ($workspaceBackend -and $Stage -eq 'Initialize') {
    Invoke-Gate 'workspace-adopt' @{context=$context; settings=(Get-WorkspaceSettings $settings); alpacaArchiveSha256=$AlpacaArchiveHash}
    return
}
if ($workspaceBackend -and $Stage -in @('BeforeCompile', 'PostCompile')) {
    throw 'Unexpected classic recompilation on prebuilt workspace backend.'
}
if (-not $workspaceBackend) {
foreach ($name in 'enableCodeCop', 'enableUICop', 'enableCodeAnalyzersOnTestApps') {
    if ((Get-Setting $settings $name) -isnot [bool] -or -not (Get-Setting $settings $name)) {
        throw "Effective analyzer setting disabled: $name"
    }
}
if ((Get-Setting $settings 'failOn') -cne 'warning') {
    throw 'Effective failOn must be warning.'
}
if ((Get-Setting $settings 'workspaceCompilation').enabled) {
    throw 'Workspace compilation bypasses these hooks; acceptance blocked pending supported integration.'
}
if ((Get-Setting $settings 'type') -cne 'AppSource App') {
    throw 'Unexpected application build type.'
}

if ($Stage -eq 'Initialize') {
    if (Test-Path -LiteralPath $directory) {
        throw 'Existing run receipts cannot be reused. Start with a clean build artifact directory.'
    }
    New-Item -Path $directory -ItemType Directory -Force | Out-Null
    $hooks = @{}
    foreach ($path in '.AL-Go/PipelineInitialize.ps1', '.AL-Go/CompileAppWithBcCompilerFolder.ps1', '.AL-Go/PostCompileApp.ps1', '.AL-Go/PipelineFinalize.ps1', '.AL-Go/settings.json', 'tools/Assert-AppSourceBuild.ps1', 'tools/appsource_gate.py', 'tools/Prepare-ClassicCompilerInputs.ps1', 'tools/Prepare-FoundationInputs.ps1', 'tools/stage_foundation_inputs.py') {
        $hooks[$path] = (Get-FileReceipt (Join-Path $Root $path)).sha256
    }
    if ($AlpacaArchiveHash -notmatch '^[a-f0-9]{64}$') {
        throw 'Downloaded Alpaca archive identity missing.'
    }
    # Capture only the intended settings, not secrets or the full Settings object.
    $effective = @{}
    foreach ($name in 'enableCodeCop', 'enableUICop', 'enableCodeAnalyzersOnTestApps', 'failOn', 'type', 'rulesetFile', 'doNotBuildTests', 'doNotRunTests', 'doNotSignApps', 'useCompilerFolder') {
        $effective[$name] = Get-Setting $settings $name
    }
    $state = @{
        context = $context
        startedNs = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000000)
        hookHashes = $hooks
        alpacaArchiveSha256 = $AlpacaArchiveHash
        effectiveSettings = $effective
        logBytes = 0
        logPrefixSha256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
        receipts = @{}
    }
    $state | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $directory 'state.json') -Encoding UTF8
    Write-Host 'AppSource gate initialized with actual run/settings/script identities.'
    return
}

if ($Stage -eq 'BeforeCompile') {
    # The only allowed non-final invocation is Alpaca's explicit translation
    # precompile: all cops disabled, CopyAppToSymbolsFolder=false, no layout.
    $translation = $CompilationParams['CopyAppToSymbolsFolder'] -eq $false -and $CompilationParams['GenerateReportLayout'] -eq 'No'
    foreach ($name in 'enableCodeCop', 'enableUICop', 'enableAppSourceCop', 'enablePerTenantExtensionCop') {
        $translation = $translation -and $CompilationParams.ContainsKey($name) -and $CompilationParams[$name] -eq $false
    }
    $kind = if ($translation) { 'translation' } else { 'final' }
    Invoke-Gate 'before' @{
        context = $context
        kind = $kind
        manifest = (Join-Path $CompilationParams.appProjectFolder 'app.json')
        symbolsFolder = $CompilationParams.appSymbolsFolder
        compilerSymbolsFolder = (Join-Path $CompilationParams.compilerFolder 'symbols')
    }
    & (Join-Path $Root 'tools/Prepare-FoundationInputs.ps1') -Action Validate -Root $Root -CacheRoot @($CompilationParams.appSymbolsFolder, (Join-Path $CompilationParams.compilerFolder 'symbols'))
    return
}

if ($Stage -eq 'PostCompile') {
    if (@($AppFile).Count -ne 1 -or -not $CompilationParams) {
        throw 'Missing/ambiguous returned compilation package or parameters.'
    }
    $parameters = @{}
    foreach ($name in 'enableCodeCop', 'enableUICop', 'enableAppSourceCop') {
        $value = $CompilationParams[$name]
        $parameters[$name] = ($null -ne $value -and [bool]$value -and ($value -is [bool] -or $value -is [System.Management.Automation.SwitchParameter]))
    }
    $parameters.failOn = [string]$CompilationParams['failOn']
    if ($CompilationParams['nowarn']) {
        throw 'Final compiler nowarn suppression is not authorized.'
    }
    $parameters.escapeFromCops = $false
    $parameters.workspaceCompilation = $false
    # These are effective pipeline flags; fallback removes cop keys and fails above.
    $escape = $settings.PSObject.Properties['escapeFromCops']
    if ($escape -and $escape.Value) {
        $parameters.escapeFromCops = $true
    }
    if (-not $CompilationParams.ContainsKey('compilerFolder')) {
        throw 'Container-only compiler identities cannot be collected here; supported collector required.'
    }
    $extension = Join-Path $CompilationParams.compilerFolder 'compiler/extension'
    $bin = Join-Path $extension 'bin'
    $compilerBin = Join-Path $bin $(if ($IsLinux) {'linux'} elseif ($IsMacOS) {'darwin'} else {'win32'})
    if (-not (Test-Path (Join-Path $compilerBin 'alc.*'))) { $compilerBin = $bin }
    $compiler = Join-Path $compilerBin 'alc.exe'
    if ($IsLinux -or $IsMacOS) {
        $compiler = Join-Path $compilerBin 'alc'
        if (-not (Test-Path -LiteralPath $compiler)) { $compiler = Join-Path $compilerBin 'alc.dll' }
    }
    $packageJson = Join-Path $extension 'package.json'
    $compilerPackage = Get-Content -LiteralPath $packageJson -Raw -Encoding UTF8 | ConvertFrom-Json
    $compilerFile = Get-FileReceipt $compiler
    if (-not $compilerFile.version) {
        throw 'Compiler executable file version unavailable.'
    }
    $parameters.compilerVersion = $compilerFile.version
    $parameters.compilerExtensionVersion = $compilerPackage.version
    $tools = @{ compiler = $compilerFile; compilerPackage = (Get-FileReceipt $packageJson) }
    $analyzers = Join-Path $bin 'Analyzers'
    if (-not (Test-Path -LiteralPath $analyzers)) {
        $analyzers = $bin
    }
    foreach ($name in 'CodeCop', 'UICop', 'AppSourceCop', 'Analyzers.Common') {
        $tools[$name] = Get-FileReceipt (Join-Path $analyzers "Microsoft.Dynamics.Nav.$name.dll")
    }
    $helper = Get-Command Run-AlPipeline -ErrorAction Stop
    $compileHelper = Get-Command Compile-AppWithBcCompilerFolder -ErrorAction Stop
    $tools.helper = Get-FileReceipt $helper.ScriptBlock.File
    $tools.compileHelper = Get-FileReceipt $compileHelper.ScriptBlock.File
    $tools.alpacaOverride = Get-FileReceipt (Join-Path $Root '.alpaca/Scripts/Overrides/RunAlPipeline/PreCompileApp.ps1')
    $parameters.tools = $tools
    $parameters.appManifestSha256 = (Get-FileReceipt (Join-Path $CompilationParams.appProjectFolder 'app.json')).sha256

    # No custom suppression ruleset is authorized by #78. Accept the unchanged
    # helper-generated AppSource ruleset only, or the empty test ruleset.
    $parameters.rulesetValidated = $false
    $configuredRuleset = [string](Get-Setting $settings 'rulesetFile')
    if ($configuredRuleset) {
        throw 'Configured custom ruleset requires scoped review; no silent replacement.'
    }
    $ruleset = [string]$CompilationParams['ruleset']
    if (-not $ruleset) {
        $parameters.rulesetValidated = $true
    }
    else {
        if ((Split-Path $ruleset -Leaf) -cne 'run-alpipeline.ruleset.json') {
            throw 'Unexpected final ruleset.'
        }
        $rules = Get-Content -LiteralPath $ruleset -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($rules.PSObject.Properties['rules'] -or @($rules.includedRuleSets).Count -ne 1 -or $rules.includedRuleSets[0].action -cne 'Default') {
            throw 'Helper ruleset was changed or extended.'
        }
        $copRuleset = Join-Path $CompilationParams.appProjectFolder 'appsource.default.ruleset.json'
        $original = Join-Path (Split-Path $helper.ScriptBlock.File -Parent) 'appsource.default.ruleset.json'
        if ((Get-FileReceipt $copRuleset).sha256 -cne (Get-FileReceipt $original).sha256 -or
            (Split-Path $rules.includedRuleSets[0].path -Leaf) -cne 'appsource.default.ruleset.json') {
            throw 'AppSource default ruleset provenance mismatch.'
        }
        $parameters.rulesetValidated = $true
        $parameters.ruleset = Get-FileReceipt $ruleset
        $parameters.appSourceRuleset = Get-FileReceipt $copRuleset
    }
    $sources = @()
    foreach ($file in Get-ChildItem -LiteralPath $CompilationParams.appProjectFolder -Recurse -File -Filter '*.al') {
        $sources += @{ file = $file.FullName.Substring($Root.Length).TrimStart('/', '\'); sha256 = (Get-FileReceipt $file.FullName).sha256 }
    }
    if ($sources.Count -eq 0) {
        throw 'No actual AL sources captured.'
    }
    Invoke-Gate 'post' @{
        context = $context
        appType = $AppType
        appFile = $AppFile[0]
        symbolsFolder = $CompilationParams.appSymbolsFolder
        compilerSymbolsFolder = (Join-Path $CompilationParams.compilerFolder 'symbols')
        parameters = $parameters
        sourceFiles = $sources
    }
    return
}

}

$signature = $null
if ($Stage -eq 'Signed') {
    if ($env:OS -ne 'Windows_NT' -or -not (Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue)) {
        throw 'Windows NAVX signature provider/trust/SIP unavailable; signature proof blocked.'
    }
    $files = @(Get-ChildItem -LiteralPath (Join-Path $Root '.buildartifacts/Apps') -Filter '*.app' -File)
    if ($files.Count -ne 1) {
        throw 'Missing/ambiguous actual signed shipping package.'
    }
    $verified = Get-AuthenticodeSignature -LiteralPath $files[0].FullName
    if ($verified.Status -ne 'Valid' -or -not $verified.SignerCertificate) {
        throw "NAVX signature/trust verification failed: $($verified.Status). Missing SIP/tool/trust is not a pass."
    }
    $signature = @{
        status = 'Valid'
        signerThumbprint = $verified.SignerCertificate.Thumbprint
        provider = 'Windows Get-AuthenticodeSignature'
        sha256 = (Get-FileReceipt $files[0].FullName).sha256
    }
}
Invoke-Gate $Stage.ToLowerInvariant() @{ context = $context; signature = $signature }
