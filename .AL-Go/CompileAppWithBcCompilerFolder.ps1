param([hashtable] $CompilationParams)

$ErrorActionPreference = 'Stop'
# Real helper callback installed by PipelineInitialize: capture inputs BEFORE its post-build copy
# puts the newly compiled product into the symbols folder. Forward every original
# parameter to the genuine helper; keep its error/exit behavior and output sink.
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
Compile-AppWithBcCompilerFolder @actual
