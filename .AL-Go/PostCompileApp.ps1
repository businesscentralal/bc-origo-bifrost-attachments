param(
    [string[]] $AppFile,
    [string] $AppType,
    [hashtable] $CompilationParams
)

# Build-AppsInWorkspace passes appFiles, AppType and actual workspace parameters.
# Run-AlPipeline passes AppFile, AppType and classic parameters in the same positions.
if ($CompilationParams -and $CompilationParams.ContainsKey('WorkspaceFile')) {
    & (Join-Path $env:GITHUB_WORKSPACE 'tools/Assert-AppSourceBuild.ps1') -Stage WorkspacePost -AppFile $AppFile -AppType $AppType -CompilationParams $CompilationParams
    return
}
# Run-AlPipeline passes returned package, app type and FINAL parameters positionally.
# Alpaca translation precompiles do not invoke this hook and cannot satisfy it.
& (Join-Path $env:GITHUB_WORKSPACE 'tools/Assert-AppSourceBuild.ps1') `
    -Stage PostCompile -AppFile $AppFile -AppType $AppType -CompilationParams $CompilationParams
