# Bounded source proofs only. No dependency binary or runtime trust is inferred.
function Import-DependencyReaderSource($Objects, [string]$ManifestPath, [string]$ExpectedHash, [string]$AppFolder) {
    if (-not $ManifestPath -and -not $ExpectedHash) { return }
    if (-not $ManifestPath -or $ExpectedHash -notmatch '^[a-fA-F0-9]{64}$') { throw 'Dependency source requires a manifest and its independently pinned SHA256' }
    if ((Get-Item -LiteralPath $ManifestPath).Length -gt 65536) { throw 'Dependency manifest size bound' }
    $manifestBytes = [IO.File]::ReadAllBytes($ManifestPath)
    if ($manifestBytes.Length -gt 65536) { throw 'Dependency manifest size bound' }
    if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($manifestBytes)) -ine $ExpectedHash) { throw 'Dependency manifest SHA256 mismatch' }
    $m = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
    if ($m.schemaVersion -ne 1 -or $m.repo -notmatch '^[\w.-]+/[\w.-]+$' -or $m.sourceSha -notmatch '^[a-f0-9]{40}$' -or
        $m.blob -notmatch '^[a-f0-9]{40}$' -or $m.sha256 -notmatch '^[a-f0-9]{64}$' -or
        $m.repositoryPath -notmatch '^app/src/.+\.al$' -or $m.repositoryPath -match '(^|/)\.\.(/|$)|\\' -or
        $m.objectKind -notin @('table', 'codeunit') -or -not $m.objectName -or $m.objectId -notmatch '^\d+$' -or
        $m.namespace -notmatch '^\w+(\.\w+)*$') { throw 'Unsupported dependency source identity' }
    $app = Get-Content -LiteralPath (Join-Path $AppFolder 'app.json') -Raw | ConvertFrom-Json
    $matching = @($app.dependencies | Where-Object { $_.id -ceq $m.dependency.id -and $_.name -ceq $m.dependency.name -and $_.publisher -ceq $m.dependency.publisher -and $_.version -ceq $m.dependency.version })
    if ($matching.Count -ne 1) { throw 'Dependency app identity mismatch' }
    if ((Get-Item -LiteralPath $m.sharedPath).Length -gt 2097152) { throw 'Dependency source size bound' }
    $bytes = [IO.File]::ReadAllBytes($m.sharedPath)
    if ($bytes.Length -gt 2097152) { throw 'Dependency source size bound' }
    if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)) -ine $m.sha256) { throw 'Dependency source SHA256 mismatch' }
    $header = [Text.Encoding]::UTF8.GetBytes("blob $($bytes.Length)`0")
    if ([Convert]::ToHexString([Security.Cryptography.SHA1]::HashData([byte[]]($header + $bytes))) -ine $m.blob) { throw 'Dependency Git blob mismatch' }
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    $tokens = Get-ALTokens $text
    $clean = ($tokens | ForEach-Object Value) -join ' '
    if ($clean -notmatch ('^namespace\s+' + [regex]::Escape($m.namespace).Replace('\.', '\s*\.\s*') + '\s*;') -or
        $clean -notmatch ('\b' + $m.objectKind + '\s+' + $m.objectId + '\s+"' + [regex]::Escape($m.objectName) + '"\s*\{')) { throw 'Dependency AL object identity mismatch' }
    if ([regex]::Matches($clean, '\b(?:codeunit|table|page|enum|enumextension|interface)\s+\d+\s+"[^"]+"').Count -ne 1) { throw 'Ambiguous dependency source object' }
    # Parse the bytes just verified, never a second disk read after the hash check.
    $external = Read-Source $m.sharedPath ($text -split '\r?\n')
    if ($external.Count -ne 1 -or -not $external.ContainsKey($m.objectName) -or $Objects.ContainsKey($m.objectName)) { throw 'Ambiguous dependency source object' }
    $Objects[$m.objectName] = $external[$m.objectName]
    Write-Host "Dependency reader source: $($m.repo)@$($m.sourceSha) $($m.repositoryPath) blob=$($m.blob); source-only, runtime unverified"
}

function Get-ProcedureTree([string]$Body) {
    $tokens = Get-ALTokens $Body
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        if ($tokens[$i].Value -eq 'begin') { return @{ Tokens = $tokens; Node = (Get-ALStatement $tokens $i) } }
    }
    throw 'Missing procedure body'
}

function Resolve-SourceCall($Objects, [string]$ObjectName, $Types, $Call) {
    if ($Call.Chained) { return $null }
    $target = $ObjectName
    if ($Call.Receiver -and $Call.Receiver -ne 'this') {
        if ($Types[$Call.Receiver] -notmatch '^(?:Codeunit|Record)\s+"([^"]+)"$') { return $null }
        $target = $Matches[1]
    }
    if (-not $Objects.ContainsKey($target) -or -not $Objects[$target].Procedures.ContainsKey($Call.Callee) -or
        @($Objects[$target].Procedures[$Call.Callee]).Count -ne 1) { return $null }
    $body = $Objects[$target].Procedures[$Call.Callee][0]
    $formals = Get-FormalParameters $body
    if ($formals.Count -ne $Call.Args.Count) { return $null }
    return @{ Object = $target; Body = $body; Formals = $formals }
}

# Accept only an unconditional acquisition, a straight forwarding call, or the
# canonical success/failure wrapper. Every output token must be accounted for.
# This deliberately rejects loops, aliases, extra assignments and ambiguous branches.
function Get-RequestOutputProof($Objects, [string]$ObjectName, [string]$Procedure, [int]$Position, $State, [int]$Depth = 0) {
    $State.Count++
    if ($Depth -gt 16 -or $State.Count -gt 256) { return $null }
    $key = "$ObjectName::$Procedure/$Position"
    if ($State.Active.ContainsKey($key)) { return $null }
    if (-not $Objects.ContainsKey($ObjectName) -or @($Objects[$ObjectName].Procedures[$Procedure]).Count -ne 1) { return $null }
    $body = $Objects[$ObjectName].Procedures[$Procedure][0]
    $formals = Get-FormalParameters $body
    if ($Position -ge $formals.Count -or -not $formals[$Position].ByRef -or $formals[$Position].Type -ne 'JsonObject') { return $null }
    $name = $formals[$Position].Name
    $State.Active[$key] = $true
    try {
        $tree = Get-ProcedureTree $body; $tokens = $tree.Tokens
        $nodes = @($tree.Node.Children)
        $types = Get-ContextTypes $Objects[$ObjectName] $body
        $execTokens = @($tokens[$tree.Node.Start..($tree.Node.Next - 1)])
        $uses = @($execTokens | Where-Object { $_.Value -eq $name }).Count
        if ($nodes.Count -eq 1 -and $nodes[0].Kind -eq 'raw') {
            $text = (Get-NodeText $nodes[0] $tokens $body).Trim()
            if ($text -match ('^' + [regex]::Escape($name) + '\s*:=\s*(\w+)\.GetRequestJson\(\)\s*;$') -and
                $types[$Matches[1]] -eq 'Record "Message Argument ori"' -and $uses -eq 1) {
                return @{ SuccessOnly = $Objects[$ObjectName].TryFunctions.ContainsKey($Procedure); Proof = $key }
            }
        }
        $offset = 0
        if ($nodes.Count -gt 0 -and (Get-NodeText $nodes[0] $tokens $body).Trim() -match ('^Clear\(\s*' + [regex]::Escape($name) + '\s*\);$')) { $offset = 1 }
        if ($nodes.Count -le $offset) { return $null }
        $node = $nodes[$offset]
        $successOnly = $false
        if ($node.Kind -eq 'if') {
            if ($node.No -or (Get-NodeText $node.Yes $tokens $body).Trim() -notmatch '^exit\(true\);$') { return $null }
            if ($nodes.Count -lt ($offset + 2) -or (Get-NodeText $nodes[-1] $tokens $body).Trim() -notmatch '^exit\(false\);$') { return $null }
            # No alternate successful exits, compound condition, or output use in the error tail.
            foreach ($tail in @($nodes | Select-Object -Skip ($offset + 1) | Select-Object -SkipLast 1)) {
                if ($tail.Kind -ne 'raw' -or $tail.Exit -or (Get-NodeText $tail $tokens $body) -match '\b(exit|error)\s*\(') { return $null }
            }
            $callText = $node.Test -join ' '; $successOnly = $true
        } elseif ($node.Kind -eq 'raw' -and $nodes.Count -eq ($offset + 1)) {
            $callText = (Get-NodeText $node $tokens $body).Trim().TrimEnd(';')
        } else { return $null }
        $calls = @(Get-ContextCalls $callText)
        if ($calls.Count -ne 1 -or $uses -ne (1 + $offset)) { return $null }
        $call = $calls[0]
        # The whole expression must be the call, with no NOT/AND/OR or nested calls.
        $expected = $(if ($call.Receiver) { $call.Receiver + '.' } else { '' }) + $call.Callee + '(' + ($call.Args -join ',') + ')'
        if (($callText -replace '\s', '') -ine ($expected -replace '\s', '')) { return $null }
        $resolved = Resolve-SourceCall $Objects $ObjectName $types $call
        if (-not $resolved) { return $null }
        $positions = @(0..($call.Args.Count - 1) | Where-Object { $call.Args[$_].Trim() -eq $name })
        if ($positions.Count -ne 1) { return $null }
        $proof = Get-RequestOutputProof $Objects $resolved.Object $call.Callee $positions[0] $State ($Depth + 1)
        if (-not $proof -or ($proof.SuccessOnly -and -not $successOnly)) { return $null }
        # A forwarding TryFunction can fail even when its callee is unconditional.
        # Preserve this hop's requirement as well as validating the callee above.
        return @{ SuccessOnly = ($successOnly -or $Objects[$ObjectName].TryFunctions.ContainsKey($Procedure)); Proof = "$key -> $($proof.Proof)" }
    } catch { return $null } finally { $State.Active.Remove($key) }
}

function Get-RequestOutputRanges($Objects, [string]$ObjectName, [string]$Body, $Types, $Diagnostics) {
    $ranges = [Collections.Generic.List[object]]::new()
    # Only attempt the bounded tree when a call actually has an output JsonObject.
    $candidates = @{}
    foreach ($call in (Get-ContextCalls $Body)) {
        $resolved = Resolve-SourceCall $Objects $ObjectName $Types $call
        if (-not $resolved) { continue }
        for ($i = 0; $i -lt $call.Args.Count; $i++) {
            if ($resolved.Formals[$i].ByRef -and $resolved.Formals[$i].Type -eq 'JsonObject' -and $Types[$call.Args[$i]] -eq 'JsonObject') {
                $state = @{ Count = 0; Active = @{} }
                $proof = Get-RequestOutputProof $Objects $resolved.Object $call.Callee $i $state
                if ($proof) { $candidates[$call.Index] = @{ Name = $call.Args[$i]; Proof = $proof; Call = $call } }
            }
        }
    }
    if ($candidates.Count -eq 0) { return ,$ranges }
    try { $tree = Get-ProcedureTree $Body } catch {
        [void]$Diagnostics.Add("${ObjectName}: unsupported output control flow"); return ,$ranges
    }
    function Visit-OutputNode($Node, [int]$End) {
        $tokens = $tree.Tokens
        if ($Node.Kind -eq 'block') {
            foreach ($child in $Node.Children) { Visit-OutputNode $child $tokens[$Node.Next - 1].Index }
        } elseif ($Node.Kind -eq 'if') {
            $testText = $Node.Test -join ' '; $testCalls = @(Get-ContextCalls $testText)
            $start = $tokens[$Node.Start].Index; $yesStart = $tokens[$Node.Yes.Start].Index
            foreach ($candidate in $candidates.Values) {
                $call = $candidate.Call
                $expected = $(if ($call.Receiver) { $call.Receiver + '.' } else { '' }) + $call.Callee + '(' + ($call.Args -join ',') + ')'
                if ($call.Index -gt $start -and $call.Index -lt $yesStart -and $testCalls.Count -eq 1 -and
                    ($testText -replace '\s', '') -ieq ($expected -replace '\s', '')) {
                    $ranges.Add(@{ Name = $candidate.Name; Start = $yesStart; End = $tokens[$Node.Yes.Next - 1].Index; Producer = $call.Index })
                }
            }
            Visit-OutputNode $Node.Yes $tokens[$Node.Yes.Next - 1].Index
            if ($Node.No) { Visit-OutputNode $Node.No $tokens[$Node.No.Next - 1].Index }
        } elseif ($Node.Kind -eq 'raw') {
            $text = (Get-NodeText $Node $tokens $Body).Trim().TrimEnd(';')
            foreach ($candidate in $candidates.Values) {
                $call = $candidate.Call
                $expected = $(if ($call.Receiver) { $call.Receiver + '.' } else { '' }) + $call.Callee + '(' + ($call.Args -join ',') + ')'
                if (-not $candidate.Proof.SuccessOnly -and ($text -replace '\s', '') -ieq ($expected -replace '\s', '')) {
                    $ranges.Add(@{ Name = $candidate.Name; Start = $tokens[$Node.Next - 1].Index + 1; End = $End; Producer = $call.Index })
                }
            }
        }
    }
    Visit-OutputNode $tree.Node $Body.Length
    foreach ($range in $ranges) {
        # Output bindings are source ranges, not the static caller bindings. Do not
        # let an assignment escape that proof through an untracked JSON reference.
        # Conservatively reject even read-only/reassigned aliases; no alias proof
        # is inferred. Tokens ignore comments and preserve assignment source order.
        for ($i = 0; $i -lt $tree.Tokens.Count; $i++) {
            $token = $tree.Tokens[$i]
            if ($token.Index -lt $range.Start -or $token.Index -gt $range.End -or $token.Value -ne ':=') { continue }
            for ($j = $i + 1; $j -lt $tree.Tokens.Count -and $tree.Tokens[$j].Value -ne ';'; $j++) {
                if ($tree.Tokens[$j].Value -eq $range.Name) {
                    $range.End = $token.Index - 1
                    [void]$Diagnostics.Add("${ObjectName}: unsupported output request alias assignment ($($range.Name))")
                    break
                }
            }
        }
        foreach ($call in (Get-ContextCalls $Body)) {
            if ($call.Index -lt $range.Start -or $call.Index -gt $range.End) { continue }
            $mutates = $call.Receiver -eq $range.Name -and $call.Callee -notin @('get', 'contains', 'keys', 'values', 'writeto')
            if ($call.Args -contains $range.Name) {
                $resolved = Resolve-SourceCall $Objects $ObjectName $Types $call
                $pos = [array]::IndexOf($call.Args, $range.Name)
                if (-not $resolved -or -not (Test-RequestParameterReadOnly $Objects $resolved.Object $call.Callee $pos @{ Count = 0; Active = @{} })) { $mutates = $true }
            }
            if ($mutates) {
                $range.End = $call.Index - 1
                [void]$Diagnostics.Add("${ObjectName}: output request may be mutated ($($range.Name))")
            }
        }
        foreach ($token in $tree.Tokens) {
            if ($token.Index -lt $range.Start -or $token.Index -gt $range.End -or $token.Value -ne $range.Name) { continue }
            if ($Body.Substring($token.Index) -match ('^' + [regex]::Escape($range.Name) + '\s*:=')) {
                $range.End = $token.Index - 1
                [void]$Diagnostics.Add("${ObjectName}: output request reassigned ($($range.Name))")
            }
        }
    }
    return ,$ranges
}

function Get-ValuesAtCall($Values, $Mutations, $OutputRanges, [int]$Index) {
    $atCall = $Values.Clone()
    foreach ($name in $Mutations.Keys) { if ($Index -gt $Mutations[$name]) { $atCall[$name] = '?' } }
    foreach ($range in $OutputRanges) { if ($Index -ge $range.Start -and $Index -le $range.End) { $atCall[$range.Name] = 'request' } }
    return $atCall
}

# JsonObject is a reference type even without VAR. Only source-proven read-only
# forwarding preserves an existing request; aliases and unknown uses fail closed.
function Test-RequestParameterReadOnly($Objects, [string]$ObjectName, [string]$Procedure, [int]$Position, $State, [int]$Depth = 0) {
    $State.Count++
    if ($Depth -gt 16 -or $State.Count -gt 256) { return $false }
    $key = "$ObjectName::$Procedure/$Position"
    if ($State.Active.ContainsKey($key) -or -not $Objects.ContainsKey($ObjectName) -or @($Objects[$ObjectName].Procedures[$Procedure]).Count -ne 1) { return $false }
    $body = $Objects[$ObjectName].Procedures[$Procedure][0]
    $formals = Get-FormalParameters $body
    if ($Position -ge $formals.Count -or $formals[$Position].Type -ne 'JsonObject' -or $formals[$Position].ByRef) { return $false }
    $name = $formals[$Position].Name; $State.Active[$key] = $true
    try {
        $types = Get-ContextTypes $Objects[$ObjectName] $body
        $tokens = Get-ALTokens $body
        $begin = @($tokens | Where-Object { $_.Value -eq 'begin' } | Select-Object -First 1)
        if ($begin.Count -ne 1) { return $false }
        $uses = @($tokens | Where-Object { $_.Index -gt $begin[0].Index -and $_.Value -eq $name })
        $covered = 0
        foreach ($call in (Get-ContextCalls $body)) {
            if ($call.Receiver -eq $name) {
                if ($call.Callee -notin @('get', 'contains', 'keys', 'values', 'writeto')) { return $false }
                $covered++
            }
            for ($i = 0; $i -lt $call.Args.Count; $i++) {
                if ($call.Args[$i].Trim() -ne $name) { continue }
                $resolved = Resolve-SourceCall $Objects $ObjectName $types $call
                if (-not $resolved -or -not (Test-RequestParameterReadOnly $Objects $resolved.Object $call.Callee $i $State ($Depth + 1))) { return $false }
                $covered++
            }
        }
        return $covered -eq $uses.Count
    } finally { $State.Active.Remove($key) }
}
