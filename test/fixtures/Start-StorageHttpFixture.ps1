# Owned-container test fixture only. Bind loopback; never expose a public listener.
[CmdletBinding()]
param([string]$DataDirectory = 'C:\Windows\Temp\worker8-168-http-fixture')
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $DataDirectory -Force | Out-Null
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add('http://localhost:9626/')
$listener.Start()
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        try {
            if ($request.Url.AbsolutePath -cnotmatch '^/(W8168[A-Za-z0-9_.-]*)/(w8168[A-Za-z0-9_.-]*)$') {
                $response.StatusCode = 400
                continue
            }
            $directory = Join-Path $DataDirectory $Matches[1]
            $file = Join-Path $directory $Matches[2]
            switch ($request.HttpMethod) {
                'GET' {
                    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { $response.StatusCode = 404; break }
                    $bytes = [System.IO.File]::ReadAllBytes($file)
                    $response.ContentType = 'application/octet-stream'
                    $response.ContentLength64 = $bytes.Length
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                }
                'POST' {
                    if ($request.ContentLength64 -lt 0 -or $request.ContentLength64 -gt 10485760) { $response.StatusCode = 413; break }
                    New-Item -ItemType Directory -Path $directory -Force | Out-Null
                    $destination = [System.IO.File]::Create($file)
                    try { $request.InputStream.CopyTo($destination) } finally { $destination.Dispose() }
                    $response.StatusCode = 204
                }
                'DELETE' {
                    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { $response.StatusCode = 404; break }
                    Remove-Item -LiteralPath $file
                    $response.StatusCode = 204
                }
                default { $response.StatusCode = 405 }
            }
        } catch { $response.StatusCode = 500 }
        finally { $response.Close() }
    }
} finally { $listener.Stop(); $listener.Close() }
