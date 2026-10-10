param(
    [string] $AppType,
    [ref] $CompilationParameters
)
$ErrorActionPreference = 'Stop'
if (-not $CompilationParameters -or $CompilationParameters.Value -isnot [hashtable]) { throw 'Actual workspace ref parameters absent.' }
& (Join-Path $env:GITHUB_WORKSPACE 'tools/Assert-AppSourceBuild.ps1') -Stage WorkspaceBefore -AppType $AppType -CompilationParams $CompilationParameters.Value
