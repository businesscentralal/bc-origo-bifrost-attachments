param(
    [string] $Root = $env:GITHUB_WORKSPACE,
    [string] $Destination,
    [switch] $FunctionsOnly
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-FoundationResolverSettings {
    param([string] $Settings)
    $copy = $Settings | ConvertFrom-Json
    $repo = 'https://github.com/OrigoSoftwareSolutions/bc-origo-bifrost-core'
    $found = @($copy.appDependencyProbingPaths | Where-Object { $_.repo.TrimEnd('/') -ieq $repo })
    if ($found.Count -ne 1) { throw 'Expected exactly one Foundation probe.' }
    $probe = $found[0]
    $expected = @{repo=$repo; release_status='latestBuild'; version='1.0.3.530'; projects='*'; authTokenSecret='ghTokenWorkflow'}
    if (@($probe.PSObject.Properties).Count -ne $expected.Count) { throw 'Unsupported Foundation probe fields.' }
    foreach ($key in $expected.Keys) {
        if ([string]$probe.$key -cne $expected[$key]) { throw 'Unsupported Foundation probe value.' }
    }
    # Preserve every other effective setting; never write the full Settings to disk/logs.
    $copy.appDependencyProbingPaths = @($copy.appDependencyProbingPaths | Where-Object { $_ -ne $probe })
    return ($copy | ConvertTo-Json -Depth 100 -Compress)
}

function Invoke-FoundationRequest {
    param([uri] $Uri, [string] $Token, [string] $OutFile, [datetime] $Deadline)
    # No automatic redirects: authorization is sent only to api.github.com.
    Add-Type -AssemblyName System.Net.Http
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [timespan]::FromSeconds(30)
    try {
        for ($redirect = 0; $redirect -le 1; $redirect++) {
            if ([datetime]::UtcNow -ge $Deadline) { throw 'Foundation acquisition deadline exceeded.' }
            $api = $Uri.Scheme -ceq 'https' -and $Uri.Host -ceq 'api.github.com'
            $blob = $Uri.Scheme -ceq 'https' -and ($Uri.Host.EndsWith('.blob.core.windows.net') -or $Uri.Host.EndsWith('.actions.githubusercontent.com'))
            if ($Uri.UserInfo -or $Uri.Port -ne 443 -or ($redirect -eq 0 -and -not $api) -or ($redirect -eq 1 -and -not $blob)) {
                throw 'Foundation download host refused.'
            }
            $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $Uri)
            $request.Headers.UserAgent.ParseAdd('Bifrost-Foundation-Input/1')
            if ($api) {
                $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token)
                $request.Headers.Accept.ParseAdd('application/vnd.github+json')
                $request.Headers.Add('X-GitHub-Api-Version', '2022-11-28')
            }
            $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            try {
                if ([int]$response.StatusCode -eq 302 -and $OutFile -and $redirect -eq 0) {
                    $Uri = $response.Headers.Location
                    continue
                }
                if (-not $response.IsSuccessStatusCode) { throw 'Foundation artifact API/download rejected.' }
                $cap = if ($OutFile) { 128MB } else { 1MB }
                if ($response.Content.Headers.ContentLength -gt $cap) { throw 'Foundation response exceeds bound.' }
                $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                $sink = if ($OutFile) { [System.IO.File]::Open($OutFile, 'CreateNew', 'Write', 'None') } else { [System.IO.MemoryStream]::new() }
                try {
                    $buffer = New-Object byte[] 65536
                    $total = 0
                    while ($true) {
                        $remaining = $Deadline - [datetime]::UtcNow
                        if ($remaining.TotalMilliseconds -le 0) { throw 'Foundation acquisition deadline exceeded.' }
                        $readTask = $stream.ReadAsync($buffer, 0, $buffer.Length)
                        if (-not $readTask.Wait([int][math]::Min(30000, $remaining.TotalMilliseconds))) { throw 'Foundation response read timed out.' }
                        $count = $readTask.GetAwaiter().GetResult()
                        if ($count -eq 0) { break }
                        $total += $count
                        if ($total -gt $cap) { throw 'Foundation response exceeds bound.' }
                        $sink.Write($buffer, 0, $count)
                    }
                    if (-not $OutFile) { return ([System.Text.Encoding]::UTF8.GetString($sink.ToArray()) | ConvertFrom-Json) }
                }
                finally { $sink.Dispose(); $stream.Dispose() }
                return
            }
            finally { $response.Dispose(); $request.Dispose() }
        }
        throw 'Unsupported Foundation redirect.'
    }
    catch { throw 'Foundation bounded API/download failed; authenticated diagnostics withheld.' }
    finally { $client.Dispose(); $handler.Dispose() }
}

function Save-FoundationArchives {
    param([string] $Token, [string] $Destination)
    if (-not $Token) { throw 'Existing ghTokenWorkflow secret unavailable.' }
    if (Test-Path -LiteralPath $Destination) { throw 'Archive retention directory already exists.' }
    $deadline = [datetime]::UtcNow.AddSeconds(120)
    $api = 'https://api.github.com/repos/OrigoSoftwareSolutions/bc-origo-bifrost-core/actions'
    $source = '8ec074f4ac69ac9bde15807cf16d21bee045332f'
    $runId = 37679390622
    $run = Invoke-FoundationRequest -Uri "$api/runs/$runId" -Token $Token -Deadline $deadline
    if ($run.id -ne $runId -or $run.head_sha -cne $source -or $run.run_attempt -ne 1 -or $run.status -cne 'completed' -or $run.conclusion -cne 'success') {
        throw 'Unapproved Foundation source run/attempt/status.'
    }
    $pins = @{
        Apps = @{ id=11508979803; sha='21c6331c47d3134d1f3c8c77f240d021fa47710f6fbdebc974b733e0b708bad8' }
        TestApps = @{ id=11510930013; sha='0a4a24e4fa1afc56e60c00ea807d8cd9a91f55f21f144c81f458e14521bd0e73' }
    }
    New-Item -ItemType Directory -Path $Destination | Out-Null
    try {
        $artifacts = @{}
        foreach ($kind in 'Apps', 'TestApps') {
            $pin = $pins[$kind]
            $meta = Invoke-FoundationRequest -Uri "$api/artifacts/$($pin.id)" -Token $Token -Deadline $deadline
            if ($meta.id -ne $pin.id -or $meta.expired -isnot [bool] -or $meta.expired -or
                $meta.workflow_run.id -ne $runId -or $meta.workflow_run.head_sha -cne $source -or
                $meta.digest -cne "sha256:$($pin.sha)" -or $meta.size_in_bytes -le 0 -or $meta.size_in_bytes -gt 128MB -or
                [datetime]::Parse($meta.expires_at).ToUniversalTime() -le [datetime]::UtcNow -or
                $meta.name -cne "bc-origo-bifrost-core-main-$kind-1.0.3.530") {
                throw 'Unapproved Foundation artifact metadata.'
            }
            $archive = Join-Path $Destination "$kind.zip"
            Invoke-FoundationRequest -Uri "$api/artifacts/$($pin.id)/zip" -Token $Token -OutFile $archive -Deadline $deadline
            if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -cne $pin.sha) { throw 'Changed Foundation archive bytes.' }
            $artifacts[$kind] = @{
                archive=$archive
                provenance=@{repository='OrigoSoftwareSolutions/bc-origo-bifrost-core'; sourceSha=$source; run=$runId; attempt=1; artifactId=$pin.id; archiveSha256=$pin.sha; expired=$false; conclusion='success'}
            }
        }
        $manifest = Join-Path $Destination 'archives.json'
        @{profile='candidate530'; artifacts=$artifacts} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifest -Encoding UTF8
        return $manifest
    }
    catch {
        # This newly created directory belongs to this invocation only.
        Remove-Item -LiteralPath $Destination -Recurse -Force
        throw 'Foundation archive acquisition failed; no selected input emitted.'
    }
}

if ($FunctionsOnly) { return }
$resolverSettings = Get-FoundationResolverSettings -Settings $env:Settings
$secretValues = $env:Secrets | ConvertFrom-Json
$token = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String([string]$secretValues.ghTokenWorkflow))
$manifest = Save-FoundationArchives -Token $token -Destination $Destination
# Settings is a step output only; never emit it on the console.
Add-Content -LiteralPath $env:GITHUB_OUTPUT -Encoding UTF8 -Value "ResolverSettings=$resolverSettings"
Add-Content -LiteralPath $env:GITHUB_OUTPUT -Encoding UTF8 -Value "ArchiveManifestPath=$manifest"
Write-Host 'Foundation archives retained separately; exact resolver probe excluded for dependency resolution.'
