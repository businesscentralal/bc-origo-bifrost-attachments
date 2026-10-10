param([hashtable] $CompilationParams)

$ErrorActionPreference = 'Stop'
# Real helper callback installed by PipelineInitialize: capture inputs BEFORE its post-build copy
# puts the newly compiled product into the symbols folder. Forward every original
# parameter to the genuine helper; keep its error/exit behavior and output sink.
$lockPath = Join-Path $env:RUNNER_TEMP "classic-custody-$env:GITHUB_RUN_ID-$env:GITHUB_RUN_ATTEMPT-$env:GITHUB_JOB-$env:BuildMode.lock"
$lock = [IO.File]::Open($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
& (Join-Path $env:GITHUB_WORKSPACE 'tools/Prepare-ClassicCompilerInputs.ps1') -Action Prepare -CompilationParams $CompilationParams
& (Join-Path $env:GITHUB_WORKSPACE 'tools/Assert-AppSourceBuild.ps1') -Stage BeforeCompile -CompilationParams $CompilationParams
$compileLog = Join-Path $env:GITHUB_WORKSPACE ".buildartifacts/AppSourceGate/$env:BuildMode/current-compile.txt"
[System.IO.File]::WriteAllText($compileLog, '')
$forwardOutput = $CompilationParams['OutputTo']
if (-not ($forwardOutput -is [scriptblock])) {
    throw 'Actual helper compiler output callback unavailable.'
}
$actual = $CompilationParams.Clone()
$actual.OutputTo = {
    param($Line)
    [System.IO.File]::AppendAllText($compileLog, ([string]$Line + [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
    $forwardOutput.Invoke($Line) | Out-Null
}.GetNewClosure()
& (Join-Path $env:GITHUB_WORKSPACE 'tools/Prepare-ClassicCompilerInputs.ps1') -Action Seal -CompilationParams $CompilationParams
$appFiles = @(Compile-AppWithBcCompilerFolder @actual)
& (Join-Path $env:GITHUB_WORKSPACE 'tools/Prepare-ClassicCompilerInputs.ps1') -Action After -CompilationParams $CompilationParams -AppFiles $appFiles
$appFiles
}
finally {
    $lock.Dispose()
    Remove-Item -LiteralPath $lockPath -Force
}
