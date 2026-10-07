<#
.SYNOPSIS
    Fails when a message type's contract and its code disagree about the request parameter names (#357, #146 rule 6).

.DESCRIPTION
    A contract lists the parameter names a caller may send under data (the "parameters" chapter). Nothing used to
    compare that list with the keys the implementation reads, so a key renamed in the contract only, or read in the
    code and never documented, stayed unnoticed. This guard reads the AL source under app/src and, for every message
    type that has a contract:

      declared-not-read  A shared-builder parameter without a proven Get/Contains read on the request.
      read-not-declared  A proven request read absent from parameters and target chapters.
      no-reads-seen      Parameters are declared but no request read can be established.
      unsupported-analysis  A reached source path cannot be resolved safely; this is a failing
                         source-analysis limitation, not a proven product defect.

    GetParameters Text literals are specialized per invocation through equality/inequality,
    literal IN/NOT IN, case alternatives, nested branches and early exits. Unknown or mutable
    selectors retain possible declarations and report unresolved analysis. The existing
    conservative Boolean-false specialization is retained (#401, #590).

    Typed formal parameters bind the request and literal key at their actual positions, including
    request-second/key-third helpers. A helper name or a nearby string is never consumption.
    Only actual Get/Contains on a proven request, forwarding/aliases established by source, or
    a proven request-data array -> token -> object chain count. Locked labels can supply keys
    to actual reads; message text cannot. Missing helpers, ambiguous overloads/dispatch, dynamic
    keys and possible request mutations fail conservatively. Text expression specialization is
    deliberately bounded; unsupported control flow retains the complete body and reports it.
    Traversal is capped at depth 40 and 2000 contexts. This is source analysis, not runtime proof.

    Hand-built JSON contracts are not inferred. Migrate product declarations to the existing
    shared builders. External dependency source is not imported: a missing reached Foundation
    reader remains unresolved until matched immutable dependency provenance is available.

    Existing target semantics are preserved: 'data.a + data.b' declares a and b;
    'data.x.y' also declares y. The guard compares names, not full JSON paths.
    Existing allow-list entries may only shrink; new offenders and stale entries fail.
    Unsupported-analysis diagnostics cannot be allow-listed.

.PARAMETER AppFolder
    The AL app folder (default: ../app next to this script).

.PARAMETER AllowListPath
    The allow-list file (default: ContractParameterKeys.AllowList.txt next to this script).

.PARAMETER Explain
    A message type name. Prints the parameters its contract declares, the target keys and the keys the code reads, and
    exits 0 without comparing the allow-list. A name that is not a message type with a contract says so and exits 1.

.PARAMETER SelfTest
    Runs the guard against small synthetic apps and checks that it reports a declared-not-read key, a
    read-not-declared key, a new offender and a stale allow-list entry. Exits 1 when it does not.

.EXAMPLE
    ./tools/Test-ContractParameterKeys.ps1
#>
param(
    [string]$AppFolder = (Join-Path $PSScriptRoot '..\app'),
    [string]$AllowListPath = (Join-Path $PSScriptRoot 'ContractParameterKeys.AllowList.txt'),
    [switch]$SelfTest,
    [string]$Explain = ''
)

$ErrorActionPreference = 'Stop'

# The procedures of "Message Argument ori" that read keys from the request, by name (lower case): the evaluate*, tryevaluate* and
# apply* readers, the table and date range readers, and FindBankAccReconciliation (systemId, recordSystemId, bankAccountNo, statementNo).
$script:ArgumentReaders = '^(evaluate|tryevaluate|apply|gettableidfromrequestjson$|getdatetimerangefromrequestjson$|findbankaccreconciliation$)'

# Keys the platform reads for every call or that are not parameters under data.
$script:NeverParameters = @('data', 'subject', 'type', 'version')

$procedureStart = [regex]::new('^\s*(\[[^\]]*\]\s*)*((local|internal|protected)\s+)?(procedure|trigger)\s+("[^"]+"|\w+)', 'IgnoreCase')
$objectStart = [regex]::new('^\s*(codeunit|table|page|enum|enumextension|interface)\s+\d*\s*"([^"]+)"', 'IgnoreCase')
$varDeclaration = [regex]::new('(?<![\w])(\w+)\s*:\s*(?:Codeunit|Record|Interface)\s+"([^"]+)"', 'IgnoreCase')
$callQualified = [regex]::new('\b(\w+)\.(\w+)\(', 'IgnoreCase')
$codeunitReference = [regex]::new('Codeunit::"([^"]+)"', 'IgnoreCase')
$callUnqualified = [regex]::new('(?<![\.\w])(\w+)\(', 'IgnoreCase')
$labelLiteral = [regex]::new("Label\s+'((?:[^']|'')*)'", 'IgnoreCase')
$stringLiteral = [regex]::new("'((?:[^']|'')*)'")
$targetLiteral = [regex]::new("TargetEntry\(\s*'data\.([^']+)'", 'IgnoreCase')
$addRangeTail = '\.AddRange\(\s*((?:''[^'']+''\s*,?\s*)+)\)'
$parameterLiteral = [regex]::new("\.Parameter\(\s*'([^']+)'", 'IgnoreCase')
# Any call, with its argument list (no nested calls): the request can be passed in any position, not only the first (#431).
$callWithArgs = [regex]::new('(?<![.\w])(?:(?<receiver>\w+)\.)?(?<callee>\w+)\s*\((?<args>[^()]*)\)', 'IgnoreCase')
# Every call, whatever its arguments: the same start as $callWithArgs, or a call through a chain ('GetParts().AddBase(' or 'A.B.C(').
$anyCall = [regex]::new('(?<![.\w])(?:(?<receiver>\w+)\.)?(?<callee>\w+)\s*\(|(?<=[\w)\]]\s*\.\s*)(?<chained>\w+)\s*\(', 'IgnoreCase')
function Read-Source([string]$AppSrc) {
    $objects = @{}
    foreach ($file in Get-ChildItem -LiteralPath $AppSrc -Recurse -Filter '*.al') {
        $lines = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8)
        $objectName = $null
        $kind = $null
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $m = $objectStart.Match($lines[$i])
            if ($m.Success) { $kind = $m.Groups[1].Value.ToLowerInvariant(); $objectName = $m.Groups[2].Value; $objectLine = $i; break }
        }
        if (-not $objectName) { continue }
        if (-not $objects.ContainsKey($objectName)) {
            $header = ($lines | Select-Object -Skip $objectLine -First 4) -join ' '
            $implements = @()
            $im = [regex]::Match($header, 'implements\s+(.*?)(?:\{|$)', 'IgnoreCase')
            if ($im.Success) { foreach ($n in [regex]::Matches($im.Groups[1].Value, '"([^"]+)"')) { $implements += $n.Groups[1].Value } }
            $tableNoMatch = [regex]::Match(($lines | Select-Object -First 40) -join ' ', 'TableNo\s*=\s*"([^"]+)"')
            $objects[$objectName] = @{ TableNo = $(if ($tableNoMatch.Success) { $tableNoMatch.Groups[1].Value } else { '' }); Implements = $implements; Name = $objectName; Kind = $kind; File = $file.FullName; Lines = $lines; Procedures = @{}; Variables = @{}; Labels = @(); Text = ($lines -join "`n") }
        }
        $object = $objects[$objectName]
        $starts = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($procedureStart.IsMatch($lines[$i])) { $starts += $i }
            foreach ($v in $varDeclaration.Matches($lines[$i])) {
                $varName = $v.Groups[1].Value.ToLowerInvariant()
                if (-not $object.Variables.ContainsKey($varName)) { $object.Variables[$varName] = @() }
                $object.Variables[$varName] += $v.Groups[2].Value
            }
            foreach ($l in $labelLiteral.Matches($lines[$i])) { $object.Labels += $l.Groups[1].Value.Replace("''", "'") }
        }
        $object.Globals = if ($starts.Count -gt 0) { ($lines | Select-Object -First $starts[0]) -join "`n" } else { $object.Text }
        for ($p = 0; $p -lt $starts.Count; $p++) {
            $name = $procedureStart.Match($lines[$starts[$p]]).Groups[5].Value.Trim('"').ToLowerInvariant()
            $to = if ($p + 1 -lt $starts.Count) { $starts[$p + 1] } else { $lines.Count }
            $body = ($lines[$starts[$p]..($to - 1)] | Where-Object { -not $_.TrimStart().StartsWith('//') }) -join "`n"
            if (-not $object.Procedures.ContainsKey($name)) { $object.Procedures[$name] = @() }
            $object.Procedures[$name] += $body
        }
    }
    return $objects
}

# In ReadMode the walk enters "Message Argument ori" only through the procedures that read the request (see the comment
# at Get-Reach). Everything else in that table is a record lookup or a response writer.
function Test-FollowCall([bool]$ReadMode, [string]$ObjectName, [string]$Callee) {
    if (-not $ReadMode -or $ObjectName -ne 'Message Argument ori') { return $true }
    return $Callee -match $script:ArgumentReaders
}

# The procedures (object, name) reachable from one procedure, following calls through typed codeunit variables and
# Codeunit::"X" references (a codeunit that is run). In ReadMode the walk enters "Message Argument ori" only through
# the evaluate*/tryevaluate*/apply* readers, which read fixed keys; the record lookups of that table read identifier
# keys that the target chapter declares. An unqualified call inside that table is followed only for those readers, so
# Evaluate* forwarding the request into TryEvaluate* still counts as a read.
function Get-Reach($Objects, [string]$ObjectName, [string]$ProcedureName, $Seen, [bool]$ReadMode = $false) {
    $key = "$ObjectName::$ProcedureName"
    if ($Seen.ContainsKey($key)) { return }
    $object = $Objects[$ObjectName]
    if (-not $object -or -not $object.Procedures.ContainsKey($ProcedureName)) { return }
    $Seen[$key] = $true
    foreach ($body in $object.Procedures[$ProcedureName]) {
        foreach ($c in $callQualified.Matches($body)) {
            $target = $c.Groups[1].Value.ToLowerInvariant()
            $callee = $c.Groups[2].Value.ToLowerInvariant()
            if ($target -eq 'rec' -and $object.TableNo) {
                # A codeunit with TableNo: Rec is that record (the Message Argument the task runs it with).
                if (Test-FollowCall $ReadMode $object.TableNo $callee) {
                    Get-Reach $Objects $object.TableNo $callee $Seen $ReadMode
                }
                continue
            }
            if ($target -in @('this', 'rec')) {
                if (Test-FollowCall $ReadMode $ObjectName $callee) { Get-Reach $Objects $ObjectName $callee $Seen $ReadMode }
                continue
            }
            if (-not $object.Variables.ContainsKey($target)) { continue }
            foreach ($t in $object.Variables[$target]) {
                if (-not $Objects.ContainsKey($t) -or $Objects[$t].Kind -eq 'interface') {
                    # An interface variable: follow the call into every codeunit that implements it.
                    foreach ($implementer in $Objects.Values) {
                        if ($implementer.Implements -contains $t) { Get-Reach $Objects $implementer.Name $callee $Seen $ReadMode }
                    }
                    continue
                }
                if (-not (Test-FollowCall $ReadMode $t $callee)) { continue }
                Get-Reach $Objects $t $callee $Seen $ReadMode
                if ($callee -eq 'run') { Get-Reach $Objects $t 'onrun' $Seen $ReadMode }
            }
        }
        foreach ($c in $callUnqualified.Matches($body)) {
            $callee = $c.Groups[1].Value.ToLowerInvariant()
            if (-not (Test-FollowCall $ReadMode $ObjectName $callee)) { continue }
            if ($object.Procedures.ContainsKey($callee)) { Get-Reach $Objects $ObjectName $callee $Seen $ReadMode }
        }
        foreach ($c in $codeunitReference.Matches($body)) {
            $t = $c.Groups[1].Value
            if ($Objects.ContainsKey($t)) { Get-Reach $Objects $t 'onrun' $Seen $ReadMode }
        }
    }
}

function Get-Types($Objects) {
    # message type name -> @{ Interface = codeunit; Contract = codeunit }
    $types = [ordered]@{}
    foreach ($object in $Objects.Values) {
        if ($object.Kind -notin @('enum', 'enumextension')) { continue }
        $text = $object.Text
        $valueMatches = [regex]::Matches($text, 'value\(\s*\d+\s*;\s*"([^"]+)"\s*\)\s*\{(.*?)\n\s*\}', 'Singleline')
        foreach ($vm in $valueMatches) {
            $implementation = [regex]::Match($vm.Groups[2].Value, 'Implementation\s*=\s*(.*?);', 'Singleline')
            if (-not $implementation.Success) { continue }
            $interfaceMatch = [regex]::Match($implementation.Groups[1].Value, '"Msg Interface ori"\s*=\s*"([^"]+)"')
            $contractMatch = [regex]::Match($implementation.Groups[1].Value, '"Msg Contract ori"\s*=\s*"([^"]+)"')
            if (-not $interfaceMatch.Success -or -not $contractMatch.Success) { continue }
            $types[$vm.Groups[1].Value] = @{ Interface = $interfaceMatch.Groups[1].Value; Contract = $contractMatch.Groups[1].Value }
        }
    }
    return $types
}

# The Boolean parameters of a procedure: lower-case name -> zero-based position.
function Get-BooleanParameters([string]$Body) {
    $result = @{}
    $signature = [regex]::Match($Body, '(?i)(?:procedure|trigger)\s+(?:"[^"]+"|\w+)\s*\(([^)]*)\)')
    if (-not $signature.Success) { return $result }
    $index = 0
    foreach ($param in $signature.Groups[1].Value.Split(';')) {
        $m = [regex]::Match($param, '(?i)^\s*(?:var\s+)?(\w+)\s*:\s*Boolean\s*$')
        if ($m.Success) { $result[$m.Groups[1].Value.ToLowerInvariant()] = $index }
        $index++
    }
    return $result
}

# The Boolean parameters that every reached call site passes as the literal false, per reached procedure
# (key "Object::procedure" -> set of lower-case names). A call that passes anything else keeps the parameter out (#401).
function Get-FalseFlags($Objects, $Seen) {
    $values = @{}
    foreach ($entry in $Seen.Keys) {
        $objectName = ($entry -split '::', 2)[0]
        $object = $Objects[$objectName]
        foreach ($body in $object.Procedures[($entry -split '::', 2)[1]]) {
            $parsedStarts = @{}
            foreach ($call in $callWithArgs.Matches($body)) {
                $parsedStarts[$call.Index] = $true
                # Not a call: the declaration of a procedure.
                if ($body.Substring(0, $call.Index) -match '(?i)\b(procedure|trigger)\s+$') { continue }
                $receiver = $call.Groups['receiver'].Value.ToLowerInvariant()
                $callee = $call.Groups['callee'].Value.ToLowerInvariant()
                $targets = @()
                if ($receiver -eq '' -or $receiver -in @('this', 'rec')) { $targets = @($objectName) }
                elseif ($object.Variables.ContainsKey($receiver)) { $targets = @($object.Variables[$receiver]) }
                $argumentList = @($call.Groups['args'].Value.Split(','))
                foreach ($targetName in $targets) {
                    $targetKey = "${targetName}::${callee}"
                    if (-not $Seen.ContainsKey($targetKey) -or -not $Objects.ContainsKey($targetName)) { continue }
                    foreach ($calleeBody in $Objects[$targetName].Procedures[$callee]) {
                        $flags = Get-BooleanParameters $calleeBody
                        foreach ($name in $flags.Keys) {
                            $position = $flags[$name]
                            $argument = if ($position -lt $argumentList.Count) { $argumentList[$position].Trim().ToLowerInvariant() } else { '?' }
                            if (-not $values.ContainsKey("$targetKey|$name")) { $values["$targetKey|$name"] = @() }
                            $values["$targetKey|$name"] += $argument
                        }
                    }
                }
            }
            # A call the pass above could not read counts as a call that may pass true (#590): one parsed call that passes false
            # must not prune a parameter that a second, unread call declares.
            foreach ($call in $anyCall.Matches($body)) {
                if ($body.Substring(0, $call.Index) -match '(?i)\b(procedure|trigger)\s+$') { continue }
                $chained = $call.Groups['chained'].Success
                $calleeName = if ($chained) { $call.Groups['chained'].Value.ToLowerInvariant() } else { $call.Groups['callee'].Value.ToLowerInvariant() }
                $receiverName = $call.Groups['receiver'].Value.ToLowerInvariant()
                $readable = $false
                $unreadTargets = @()
                if (-not $chained) {
                    if ($receiverName -eq '' -or $receiverName -in @('this', 'rec')) { $unreadTargets = @($objectName); $readable = $true }
                    elseif ($object.Variables.ContainsKey($receiverName)) { $unreadTargets = @($object.Variables[$receiverName]); $readable = $true }
                    if ($readable -and $parsedStarts.ContainsKey($call.Index)) { continue }
                }
                if (-not $readable) {
                    # A receiver the guard cannot resolve: any reached procedure of that name may be the one called.
                    $unreadTargets = @($Seen.Keys | Where-Object { $_.EndsWith("::$calleeName") } | ForEach-Object { ($_ -split '::', 2)[0] })
                }
                foreach ($targetName in $unreadTargets) {
                    $targetKey = "${targetName}::${calleeName}"
                    if (-not $Seen.ContainsKey($targetKey) -or -not $Objects.ContainsKey($targetName)) { continue }
                    foreach ($calleeBody in $Objects[$targetName].Procedures[$calleeName]) {
                        foreach ($name in (Get-BooleanParameters $calleeBody).Keys) {
                            if (-not $values.ContainsKey("$targetKey|$name")) { $values["$targetKey|$name"] = @() }
                            $values["$targetKey|$name"] += '?'
                        }
                    }
                }
            }
        }
    }
    $result = @{}
    foreach ($key in $values.Keys) {
        if (@($values[$key] | Where-Object { $_ -ne 'false' }).Count -ne 0) { continue }
        $parts = $key -split '\|', 2
        if (-not $result.ContainsKey($parts[0])) { $result[$parts[0]] = New-Object 'System.Collections.Generic.HashSet[string]' }
        [void]$result[$parts[0]].Add($parts[1])
    }
    return $result
}

# The index just after the AL statement that starts at $Start: a begin ... end block, or the text up to the next ';' (or an
# 'else', or the 'end' that closes the enclosing block) outside string literals, comments and parentheses.
# With $ToBlockEnd it is the index of the 'end' that closes the block $Start is in: the statements that follow are scanned,
# nested begin ... end blocks and case statements are skipped whole, and no ';' or 'else' ends the scan (#590).
function Get-StatementEnd([string]$Text, [int]$Start, [bool]$ToBlockEnd = $false) {
    $i = $Start
    $depth = 0
    $parens = 0
    $length = $Text.Length
    while ($i -lt $length) {
        $c = $Text[$i]
        if ($c -eq "'") {
            $i++
            while ($i -lt $length) {
                if ($Text[$i] -eq "'") {
                    if ($i + 1 -lt $length -and $Text[$i + 1] -eq "'") { $i += 2; continue }
                    break
                }
                $i++
            }
            $i++
            continue
        }
        if ($c -eq '/' -and $i + 1 -lt $length -and $Text[$i + 1] -eq '/') {
            while ($i -lt $length -and $Text[$i] -ne "`n") { $i++ }
            continue
        }
        if ($c -eq '(') { $parens++ }
        elseif ($c -eq ')') { $parens-- }
        elseif ($c -eq ';' -and $depth -eq 0 -and $parens -eq 0) { if (-not $ToBlockEnd) { return $i + 1 } }
        elseif ([char]::IsLetter($c)) {
            $j = $i
            while ($j -lt $length -and ([char]::IsLetterOrDigit($Text[$j]) -or $Text[$j] -eq '_')) { $j++ }
            $word = $Text.Substring($i, $j - $i).ToLowerInvariant()
            if ($word -eq 'begin' -or $word -eq 'case') { $depth++ }
            elseif ($word -eq 'end') {
                if ($depth -eq 0) { return $i }
                $depth--
                if ($depth -eq 0 -and -not $ToBlockEnd) { return $j }
            }
            elseif ($word -eq 'else' -and $depth -eq 0 -and $parens -eq 0 -and -not $ToBlockEnd) { return $i }
            $i = $j
            continue
        }
        $i++
    }
    return $length
}

# Takes out of a procedure body what a Boolean parameter that is always false switches off: the statement of
# 'if Flag then <statement>' and the rest of the block after 'if not Flag then exit;' (#401, #590).
function Remove-FalseFlagSpans([string]$Body, $FlagNames) {
    $ifFlag = [regex]::new('\bif\s+(?<not>not\s+)?(?<flag>\w+)\s+then\b', 'IgnoreCase')
    $hits = @($ifFlag.Matches($Body) | Where-Object { $FlagNames.Contains($_.Groups['flag'].Value.ToLowerInvariant()) })
    for ($k = $hits.Count - 1; $k -ge 0; $k--) {
        $hit = $hits[$k]
        $after = $hit.Index + $hit.Length
        if ($hit.Groups['not'].Success) {
            $exitStatement = [regex]::Match($Body.Substring($after), '(?is)^\s*exit\b[^;]*;')
            if ($exitStatement.Success) {
                # The exit leaves the procedure, so what follows it in the same block is switched off with the flag. What follows the
                # enclosing block is not: 'if A then begin if not Flag then exit; X; end; Y;' keeps Y (#590).
                $blockEnd = Get-StatementEnd $Body ($after + $exitStatement.Length) $true
                $Body = $Body.Substring(0, $hit.Index) + $Body.Substring($blockEnd)
            }
            continue
        }
        $end = Get-StatementEnd $Body $after
        $Body = $Body.Substring(0, $hit.Index) + $Body.Substring($end)
    }
    return $Body
}

# A copy of the object table in which the procedures that have an always-false flag lost what the flag switches off.
function Get-PrunedObjects($Objects, $FalseFlags) {
    $pruned = @{}
    foreach ($name in $Objects.Keys) { $pruned[$name] = $Objects[$name] }
    foreach ($entry in $FalseFlags.Keys) {
        $parts = $entry -split '::', 2
        $copy = $pruned[$parts[0]].Clone()
        $copy.Procedures = $copy.Procedures.Clone()
        $copy.Procedures[$parts[1]] = @($Objects[$parts[0]].Procedures[$parts[1]] | ForEach-Object { Remove-FalseFlagSpans $_ $FalseFlags[$entry] })
        $pruned[$parts[0]] = $copy
    }
    return $pruned
}

# Bounded call-context analysis. Values are either a proven Text literal (s:...), the
# request object (request), or unknown. Unknown never selects a branch or invents a read.
function Get-ALTokens([string]$Text) {
    $pattern = '//[^\r\n]*|/\*[\s\S]*?\*/|''(?:[^'']|'''')*''|"(?:[^"]|"")*"|\b\w+\b|<>|:=|[^\s]'
    return ,@([regex]::Matches($Text, $pattern) | Where-Object { -not $_.Value.StartsWith('//') -and -not $_.Value.StartsWith('/*') })
}

function Get-ALStatement($Tokens, [int]$Start) {
    $i = $Start
    if ($i -ge $Tokens.Count) { throw 'Unexpected end of statement' }
    $word = $Tokens[$i].Value.ToLowerInvariant()
    if ($word -eq 'begin') {
        $children = @(); $i++
        while ($i -lt $Tokens.Count -and $Tokens[$i].Value -ne 'end') {
            $node = Get-ALStatement $Tokens $i; $children += $node; $i = $node.Next
        }
        if ($i -ge $Tokens.Count) { throw 'Unclosed begin' }
        $i++
        if ($i -lt $Tokens.Count -and $Tokens[$i].Value -eq ';') { $i++ }
        return @{ Kind = 'block'; Start = $Start; Next = $i; Children = $children }
    }
    if ($word -eq 'if') {
        $i++; $condition = $i; $depth = 0
        while ($i -lt $Tokens.Count) {
            $v = $Tokens[$i].Value
            if ($v -eq 'then' -and $depth -eq 0) { break }
            if ($v -in @('(', '[')) { $depth++ }; if ($v -in @(')', ']')) { $depth-- }
            $i++
        }
        if ($i -ge $Tokens.Count) { throw 'Missing then' }
        $test = @($Tokens[$condition..($i - 1)] | ForEach-Object Value)
        $yes = Get-ALStatement $Tokens ($i + 1); $i = $yes.Next; $no = $null
        if ($i -lt $Tokens.Count -and $Tokens[$i].Value -eq 'else') { $no = Get-ALStatement $Tokens ($i + 1); $i = $no.Next }
        return @{ Kind = 'if'; Start = $Start; Next = $i; Test = $test; Yes = $yes; No = $no }
    }
    if ($word -eq 'case') {
        $i++; $selector = $i
        while ($i -lt $Tokens.Count -and $Tokens[$i].Value -ne 'of') { $i++ }
        if ($i -ge $Tokens.Count) { throw 'Missing case of' }
        $test = @($Tokens[$selector..($i - 1)] | ForEach-Object Value); $i++; $arms = @(); $otherwise = @()
        while ($i -lt $Tokens.Count -and $Tokens[$i].Value -ne 'end') {
            if ($Tokens[$i].Value -eq 'else') {
                $i++
                while ($i -lt $Tokens.Count -and $Tokens[$i].Value -ne 'end') {
                    $node = Get-ALStatement $Tokens $i; $otherwise += $node; $i = $node.Next
                }
                break
            }
            $label = $i
            while ($i -lt $Tokens.Count -and $Tokens[$i].Value -ne ':') { $i++ }
            if ($i -ge $Tokens.Count) { throw 'Missing case label' }
            $labels = @($Tokens[$label..($i - 1)] | ForEach-Object Value)
            $node = Get-ALStatement $Tokens ($i + 1); $i = $node.Next
            $arms += @{ Labels = $labels; Node = $node }
        }
        if ($i -ge $Tokens.Count) { throw 'Unclosed case' }
        $i++; if ($i -lt $Tokens.Count -and $Tokens[$i].Value -eq ';') { $i++ }
        return @{ Kind = 'case'; Start = $Start; Next = $i; Test = $test; Arms = $arms; Otherwise = $otherwise }
    }
    # Other statements are retained whole. Nested loops/try constructs are unsupported
    # for specialization: the caller falls back to the complete body with a diagnostic.
    if ($word -in @('for', 'foreach', 'while', 'repeat', 'with')) { throw "Unsupported control flow: $word" }
    $depth = 0
    while ($i -lt $Tokens.Count) {
        $v = $Tokens[$i].Value
        if ($depth -eq 0 -and $v -in @(';', 'else', 'end')) { break }
        if ($v -eq '(') { $depth++ }; if ($v -eq ')') { $depth-- }
        $i++
    }
    if ($i -eq $Start -and $Tokens[$i].Value -ne ';') { throw 'Empty statement' }
    if ($i -lt $Tokens.Count -and $Tokens[$i].Value -eq ';') { $i++ }
    return @{ Kind = 'raw'; Start = $Start; Next = $i; Exit = ($word -eq 'exit') }
}

function Get-TextCondition($Tokens, $Values) {
    $text = ($Tokens -join ' ').Trim()
    # Only equality, inequality and literal lists with a proven Text variable are
    # evaluated. In particular, runtime Booleans do not become proof of reachability.
    if ($text -match '^not\s*\((.*)\)$') {
        $nestedTokens = Get-ALTokens $Matches[1]
        $inner = Get-TextCondition @($nestedTokens | ForEach-Object Value) $Values
        if ($null -ne $inner) { return (-not $inner) }; return $null
    }
    if ($text -match '^\((.*)\)$') { $nestedTokens = Get-ALTokens $Matches[1]; return Get-TextCondition @($nestedTokens | ForEach-Object Value) $Values }
    $m = [regex]::Match($text, "^(\w+)\s*(=|<>|not\s+in|in)\s*(.*)$", 'IgnoreCase')
    if (-not $m.Success) { return $null }
    $value = $Values[$m.Groups[1].Value]
    if (-not $value -or -not $value.StartsWith('s:')) { return $null }
    $actual = $value.Substring(2); $op = $m.Groups[2].Value; $rhs = $m.Groups[3].Value
    if ($op -in @('=', '<>')) {
        if ($rhs -notmatch "^'((?:[^']|'')*)'$" ) { return $null }
        $equal = $actual -ceq $Matches[1].Replace("''", "'")
        if ($op -eq '<>') { return (-not $equal) }; return $equal
    }
    if ($rhs -notmatch "^\[\s*'(?:[^']|'')*'(?:\s*,\s*'(?:[^']|'')*')*\s*\]$") { return $null }
    $list = @($stringLiteral.Matches($rhs) | ForEach-Object { $_.Groups[1].Value.Replace("''", "'") })
    $contains = $list -ccontains $actual
    if ($op -match '^not') { return (-not $contains) }; return $contains
}

function Get-NodeText($Node, $Tokens, [string]$Body) {
    if ($Node.Next -le $Node.Start) { return '' }
    $first = $Tokens[$Node.Start]; $last = $Tokens[$Node.Next - 1]
    return $Body.Substring($first.Index, $last.Index + $last.Length - $first.Index)
}

function Select-ContextStatements($Nodes, $Tokens, [string]$Body, $Values) {
    $result = ''; $exits = $false
    foreach ($node in $Nodes) {
        $part = ''; $leaves = $false
        switch ($node.Kind) {
            'raw' { $part = Get-NodeText $node $Tokens $Body; $leaves = $node.Exit }
            'block' {
                $r = Select-ContextStatements $node.Children $Tokens $Body $Values
                $part = $r.Text; $leaves = $r.Exits
            }
            'if' {
                $condition = Get-TextCondition $node.Test $Values
                if ($null -ne $condition) {
                    $selected = if ($condition) { @($node.Yes) } elseif ($node.No) { @($node.No) } else { @() }
                    $r = Select-ContextStatements $selected $Tokens $Body $Values; $part = $r.Text; $leaves = $r.Exits
                } else {
                    $yes = Select-ContextStatements @($node.Yes) $Tokens $Body $Values
                    $no = Select-ContextStatements @($node.No | Where-Object { $_ }) $Tokens $Body $Values
                    # Keep the condition: it may contain a reached call/read.
                    $part = ($node.Test -join ' ') + "`n" + $yes.Text + "`n" + $no.Text
                    $leaves = $yes.Exits -and $no.Exits
                }
            }
            'case' {
                $value = if ($node.Test.Count -eq 1) { $Values[$node.Test[0]] } else { $null }
                $known = $value -and $value.StartsWith('s:')
                foreach ($arm in $node.Arms) {
                    if (($arm.Labels -join ' ') -notmatch "^'(?:[^']|'')*'(?:\s*,\s*'(?:[^']|'')*')*$") { $known = $false }
                }
                if ($known) {
                    $selected = $node.Otherwise
                    foreach ($arm in $node.Arms) {
                        $labels = @($stringLiteral.Matches(($arm.Labels -join ' ')) | ForEach-Object { $_.Groups[1].Value.Replace("''", "'") })
                        if ($labels -ccontains $value.Substring(2)) { $selected = @($arm.Node); break }
                    }
                    $r = Select-ContextStatements $selected $Tokens $Body $Values; $part = $r.Text; $leaves = $r.Exits
                } else {
                    $part = ($node.Test -join ' ') + "`n"
                    foreach ($arm in $node.Arms) { $part += (Select-ContextStatements @($arm.Node) $Tokens $Body $Values).Text + "`n" }
                    $part += (Select-ContextStatements $node.Otherwise $Tokens $Body $Values).Text
                }
            }
        }
        $result += $part + "`n"
        if ($leaves) { $exits = $true; break }
    }
    return @{ Text = $result; Exits = $exits }
}

# Signature metadata is procedure-local: another procedure's variable with the same
# name must never resolve this call. Ambiguous overloads are not merged into proof.
function Get-FormalParameters([string]$Body) {
    $m = [regex]::Match($Body, '(?i)(?:procedure|trigger)\s+(?:"[^"]+"|\w+)\s*\(([^)]*)\)')
    $result = @()
    if ($m.Success -and $m.Groups[1].Value.Trim()) {
        foreach ($part in $m.Groups[1].Value.Split(';')) {
            $p = [regex]::Match($part, '(?i)^\s*(?<var>var\s+)?(?<name>\w+)\s*:\s*(?<type>.+?)\s*$')
            if (-not $p.Success) { throw 'Unsupported formal parameter' }
            $result += @{ Name = $p.Groups['name'].Value.ToLowerInvariant(); Type = $p.Groups['type'].Value; ByRef = $p.Groups['var'].Success }
        }
    }
    return ,$result
}

function Get-ContextTypes($Object, [string]$Body) {
    $result = @{}
    # Global declarations are outside every procedure; local declarations override them.
    $global = $Object.Globals
    foreach ($text in @($global, $Body)) {
        $begin = [regex]::Match($text, '(?i)\bbegin\b')
        if ($begin.Success) { $text = $text.Substring(0, $begin.Index) }
        foreach ($m in [regex]::Matches($text, '(?i)\b(\w+)\s*:\s*(JsonObject|JsonArray|JsonToken|Text\b(?:\[\d+\])?|Code\b(?:\[\d+\])?|(?:Codeunit|Record|Interface)\s+"[^"]+")')) {
            $result[$m.Groups[1].Value] = $m.Groups[2].Value
        }
    }
    if ($Object.TableNo) { $result['rec'] = 'Record "' + $Object.TableNo + '"' }
    return $result
}

function Get-ContextCalls([string]$Body) {
    $tokens = Get-ALTokens $Body; $calls = @()
    for ($i = 0; $i + 1 -lt $tokens.Count; $i++) {
        if ($tokens[$i].Value -notmatch '^\w+$' -or $tokens[$i + 1].Value -ne '(') { continue }
        if ($i -gt 0 -and $tokens[$i - 1].Value -in @('procedure', 'trigger')) { continue }
        $receiver = ''; $chained = $false
        if ($i -gt 0 -and $tokens[$i - 1].Value -eq '.') {
            if ($i -gt 1 -and $tokens[$i - 2].Value -match '^\w+$' -and ($i -lt 3 -or $tokens[$i - 3].Value -ne '.')) { $receiver = $tokens[$i - 2].Value }
            else { $chained = $true }
        }
        $depth = 1; $j = $i + 2; $start = $tokens[$i + 1].Index + 1; $args = @()
        while ($j -lt $tokens.Count) {
            $v = $tokens[$j].Value
            if ($v -eq '(') { $depth++ }; if ($v -eq ')') { $depth-- }
            if (($v -eq ',' -and $depth -eq 1) -or $depth -eq 0) {
                $arg = $Body.Substring($start, $tokens[$j].Index - $start).Trim()
                if ($arg -or $args.Count -gt 0) { $args += $arg }; $start = $tokens[$j].Index + 1
            }
            if ($depth -eq 0) { break }; $j++
        }
        if ($depth -ne 0) { continue }
        $inline = ''
        if ($chained -and $i -ge 6 -and $tokens[$i - 2].Value -eq ')' -and $tokens[$i - 3].Value -eq '(' -and $tokens[$i - 4].Value -eq 'GetRequestJson' -and $tokens[$i - 5].Value -eq '.') { $inline = $tokens[$i - 6].Value }
        $calls += @{ InlineRequestReceiver = $inline; Receiver = $receiver; Callee = $tokens[$i].Value.ToLowerInvariant(); Args = $args; Index = $tokens[$i].Index; Chained = $chained }
    }
    return ,$calls
}

function Resolve-ContextValue([string]$Expression, $Values, $Types) {
    $e = $Expression.Trim()
    if ($e -match "^'((?:[^']|'')*)'$") { return 's:' + $Matches[1].Replace("''", "'") }
    if ($e -match '^\w+$' -and $Values.ContainsKey($e)) { return $Values[$e] }
    if ($e -match '^(?:(\w+)\.)?GetRequestJson\(\)$') {
        if ($Matches[1] -and $Types[$Matches[1]] -eq 'Record "Message Argument ori"') { return 'request' }
    }
    return '?'
}

function Get-ContextBindings($Object, [string]$Body, $InputValues, $Types) {
    $values = $InputValues.Clone(); $assignments = @{}
    $sourceTokens = Get-ALTokens $Body
    $tokenStarts = @{}
    foreach ($token in $sourceTokens) { $tokenStarts[$token.Index] = $true }
    # Multiple/conditional assignments and writes to a formal invalidate that value
    # for the entire procedure. This deliberately gives false positives over false proof.
    $mask = $Body
    foreach ($m in [regex]::Matches($mask, '(?im)(?<![.\w])(\w+)\s*:=\s*([^;]+);')) {
        if (-not $tokenStarts.ContainsKey($m.Index)) { continue }
        $name = $m.Groups[1].Value
        if (-not $assignments.ContainsKey($name)) { $assignments[$name] = @() }
        $assignments[$name] += $m
        $values[$name] = '?'
    }
    foreach ($label in [regex]::Matches($Body, "(?im)\b(\w+)\s*:\s*Label\s+'((?:[^']|'')*)'\s*,\s*Locked\s*=\s*true\s*;")) {
        $values[$label.Groups[1].Value] = 's:' + $label.Groups[2].Value.Replace("''", "'")
    }
    # Only straight-line aliases before the first control-flow statement are bound.
    # Request acquisition in an ordinary top-level assignment remains supported.
    $control = [regex]::Match($mask, '(?i)\b(if|case|for|foreach|while|repeat)\b')
    foreach ($name in $assignments.Keys) {
        $a = $assignments[$name]
        if ($a.Count -ne 1 -or $InputValues.ContainsKey($name) -or ($control.Success -and $a[0].Index -gt $control.Index)) { continue }
        $value = Resolve-ContextValue $a[0].Groups[2].Value $values $Types
        if ($value -eq 'request' -and $Types[$name] -ne 'JsonObject') { continue }
        $values[$name] = $value
    }
    # Resolve alias chains in source order, never a forward reference.
    foreach ($a in @($assignments.Values | ForEach-Object { $_ } | Sort-Object Index)) {
        $name = $a.Groups[1].Value
        if ($assignments[$name].Count -ne 1 -or $InputValues.ContainsKey($name) -or ($control.Success -and $a.Index -gt $control.Index)) { continue }
        $rhs = $a.Groups[2].Value.Trim()
        if ($assignments.ContainsKey($rhs) -and $assignments[$rhs][0].Index -gt $a.Index) { $values[$name] = '?'; continue }
        $values[$name] = Resolve-ContextValue $rhs $values $Types
    }
    $tokens = Get-ALTokens $Body
    $beginIndex = @($tokens | Where-Object { $_.Value -eq 'begin' } | Select-Object -First 1)
    foreach ($name in $assignments.Keys) {
        $a = $assignments[$name]
        if ($a.Count -ne 1 -or $beginIndex.Count -ne 1) { continue }
        if (@($tokens | Where-Object { $_.Value -eq $name -and $_.Index -gt $beginIndex[0].Index -and $_.Index -lt $a[0].Index }).Count -gt 0) { $values[$name] = '?' }
    }
    # A record object is request-derived only through the actual array -> token ->
    # AsObject chain, with the source operations in order (not any nearby AsObject).
    $calls = Get-ContextCalls $Body
    foreach ($getArray in @($calls | Where-Object { $_.Callee -eq 'getrequestdataarray' -and $_.Args.Count -eq 1 })) {
        if ($Types[$getArray.Receiver] -ne 'Record "Message Argument ori"') { continue }
        $array = $getArray.Args[0]
        if ($Types[$array] -ne 'JsonArray') { continue }
        if (@($calls | Where-Object { $_.Args -contains $array -and $_.Index -ne $getArray.Index }).Count -gt 0) { continue }
        if (@($calls | Where-Object { $_.Receiver -eq $array -and $_.Callee -notin @('get', 'count') }).Count -gt 0) { continue }
        foreach ($getToken in @($calls | Where-Object { $_.Receiver -eq $array -and $_.Callee -eq 'get' -and $_.Args.Count -eq 2 })) {
            if ($getToken.Index -lt $getArray.Index) { continue }
            $token = $getToken.Args[1]
            if ($Types[$token] -ne 'JsonToken') { continue }
            if (@($calls | Where-Object { $_.Args -contains $token -and $_.Index -ne $getToken.Index }).Count -gt 0) { continue }
            foreach ($name in $assignments.Keys) {
                $a = $assignments[$name]
                if ($a.Count -ne 1 -or $a[0].Index -lt $getToken.Index -or $Types[$name] -ne 'JsonObject') { continue }
                if ($a[0].Groups[2].Value.Trim() -eq "$token.AsObject()") { $values[$name] = 'request' }
            }
        }
    }
    return $values
}

function Get-ContextBody([string]$Body, $Values, $Diagnostics, [string]$Location) {
    if (@($Values.Values | Where-Object { $_ -like 's:*' }).Count -eq 0) { return $Body }
    $tokens = Get-ALTokens $Body
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        if ($tokens[$i].Value -ne 'begin') { continue }
        try {
            $tree = Get-ALStatement $tokens $i
            return $Body.Substring(0, $tokens[$i].Index) + (Select-ContextStatements @($tree) $tokens $Body $Values).Text
        } catch {
            [void]$Diagnostics.Add("${Location}: $($_.Exception.Message)")
            return $Body
        }
    }
    return $Body
}

function Get-ContextReach($Objects, [string]$ObjectName, [string]$ProcedureName, $Bindings, $Contexts, $Diagnostics, [bool]$ReadMode = $false, [int]$Depth = 0) {
    if ($Depth -gt 40 -or $Contexts.Count -gt 2000) { [void]$Diagnostics.Add("${ObjectName}::${ProcedureName}: traversal bound"); return }
    if (-not $Objects.ContainsKey($ObjectName) -or -not $Objects[$ObjectName].Procedures.ContainsKey($ProcedureName)) {
        [void]$Diagnostics.Add("${ObjectName}::${ProcedureName}: unavailable source"); return
    }
    $object = $Objects[$ObjectName]; $bodies = @($object.Procedures[$ProcedureName])
    if ($bodies.Count -ne 1) { [void]$Diagnostics.Add("${ObjectName}::${ProcedureName}: unresolved overload"); return }
    $ordered = [ordered]@{}
    foreach ($key in ($Bindings.Keys | Sort-Object)) { $ordered[$key] = $Bindings[$key] }
    $identity = "$ObjectName::$ProcedureName|" + ($ordered | ConvertTo-Json -Compress)
    if ($Contexts.ContainsKey($identity)) { return }
    $body = $bodies[0]; $types = Get-ContextTypes $object $body
    $values = Get-ContextBindings $object $body $Bindings $types
    $calls = Get-ContextCalls $body
    $mutations = @{}
    # A by-ref parameter or unknown call can mutate a selector/alias. No caller
    # literal survives that uncertainty. Passing to a proven by-value formal is safe.
    foreach ($call in $calls) {
        $target = $null
        if (-not $call.Receiver -or $call.Receiver -eq 'this') { $target = $ObjectName }
        elseif ($types[$call.Receiver] -match '^(?:Codeunit|Record)\s+"([^"]+)"$') { $target = $Matches[1] }
        $formals = @(); $resolved = $target -and $Objects.ContainsKey($target) -and $Objects[$target].Procedures.ContainsKey($call.Callee) -and @($Objects[$target].Procedures[$call.Callee]).Count -eq 1
        if ($resolved) { $formals = Get-FormalParameters $Objects[$target].Procedures[$call.Callee][0] }
        for ($a = 0; $a -lt $call.Args.Count; $a++) {
            $arg = $call.Args[$a].Trim()
            if (-not $values.ContainsKey($arg) -or ($values[$arg] -notlike 's:*' -and $values[$arg] -ne 'request')) { continue }
            $unknownTyped = $target -and -not $resolved -and $target -ne 'Msg Contract Mgt ori'
            if (($resolved -and $a -lt $formals.Count -and $formals[$a].ByRef) -or $unknownTyped) {
                if (-not $mutations.ContainsKey($arg) -or $mutations[$arg] -gt $call.Index) { $mutations[$arg] = $call.Index }
            }

        }
    }
    foreach ($name in $mutations.Keys) {
        if ($values[$name] -eq 'request') { [void]$Diagnostics.Add("${ObjectName}::${ProcedureName}: request may be mutated by call ($name)") }
    }
    # Text specialization is needed on contract builders. Read analysis keeps all
    # possible runtime branches, and binds keys only at actual member reads.
    if (-not $ReadMode) {
        foreach ($name in $mutations.Keys) { $values[$name] = '?' }
        foreach ($formal in (Get-FormalParameters $body)) {
            if ($formal.Type -notmatch '^(Text|Code)(\[\d+\])?$') { continue }
            $name = [regex]::Escape($formal.Name)
            if ($body -match "(?i)\b(?:if\s+(?:not\s*\(?\s*)?|case\s+)$name\b" -and $values[$formal.Name] -notlike 's:*') {
                [void]$Diagnostics.Add("${ObjectName}::${ProcedureName}: unresolved Text selector $($formal.Name)")
            }
        }
    }
    if (-not $ReadMode) { $body = Get-ContextBody $body $values $Diagnostics "$ObjectName::$ProcedureName" }
    $Contexts[$identity] = @{ Object = $ObjectName; Procedure = $ProcedureName; Body = $body; Values = $values; Types = $types; Mutations = $mutations }
    foreach ($call in (Get-ContextCalls $body)) {
        $callee = $call.Callee; $receiver = $call.Receiver; $target = $null
        $atCall = $values.Clone()
        foreach ($name in $mutations.Keys) { if ($call.Index -gt $mutations[$name]) { $atCall[$name] = '?' } }
        $actual = @($call.Args | ForEach-Object { Resolve-ContextValue $_ $atCall $types })
        $hasRequest = $actual -contains 'request'
        if ($call.Chained) {
            if ($ReadMode -and $call.InlineRequestReceiver -and $types[$call.InlineRequestReceiver] -eq 'Record "Message Argument ori"') { continue }
            if (-not $ReadMode -or $hasRequest) { [void]$Diagnostics.Add("${ObjectName}::${ProcedureName}: unresolved chained $callee") }
            continue
        }
        if (-not $receiver -or $receiver -eq 'this') { if ($object.Procedures.ContainsKey($callee)) { $target = $ObjectName } }
        elseif ($types[$receiver] -match '^(?:Codeunit|Record|Interface)\s+"([^"]+)"$') { $target = $Matches[1] }
        if (-not $target) {
            if ($ReadMode -and $hasRequest -and $callee -notin @('exit')) { [void]$Diagnostics.Add("${ObjectName}::${ProcedureName}: unresolved call $receiver.$callee") }
            continue
        }
        if ($target -eq 'Msg Contract Mgt ori') { continue } # Existing builder recognition, never read evidence.
        if ($ReadMode -and $target -eq 'Message Argument ori' -and -not (Test-FollowCall $true $target $callee)) {
            if (-not ($hasRequest -and @($actual | Where-Object { $_ -like 's:*' }).Count -gt 0)) { continue }
        }
        if (-not $Objects.ContainsKey($target) -or -not $Objects[$target].Procedures.ContainsKey($callee)) {
            if (-not $ReadMode -or $hasRequest -or ($target -eq 'Message Argument ori' -and $callee -match $script:ArgumentReaders)) {
                [void]$Diagnostics.Add("${target}::${callee}: unavailable source")
            }
            continue
        }
        if (@($Objects[$target].Procedures[$callee]).Count -ne 1) { [void]$Diagnostics.Add("${target}::${callee}: unresolved overload"); continue }
        $formal = Get-FormalParameters $Objects[$target].Procedures[$callee][0]
        if ($formal.Count -ne $actual.Count) { [void]$Diagnostics.Add("${target}::${callee}: argument count"); continue }
        $bound = @{}
        for ($a = 0; $a -lt $formal.Count; $a++) {
            if ($formal[$a].Type -match '^(Text|Code)(\[\d+\])?$' -and $actual[$a] -like 's:*') { $bound[$formal[$a].Name] = $actual[$a] }
            if ($formal[$a].Type -eq 'JsonObject' -and $actual[$a] -eq 'request') { $bound[$formal[$a].Name] = 'request' }
        }
        Get-ContextReach $Objects $target $callee $bound $Contexts $Diagnostics $ReadMode ($Depth + 1)
    }
    if ($ReadMode) {
        foreach ($call in (Get-ContextCalls $body)) {
            if ($call.Receiver -ne 'Codeunit' -or $call.Callee -ne 'run' -or $call.Args.Count -ne 2) { continue }
            if ($call.Args[0] -notmatch '^Codeunit::"([^"]+)"$' -or $types[$call.Args[1]] -ne 'Record "Message Argument ori"') { continue }
            $target = $Matches[1]
            Get-ContextReach $Objects $target 'onrun' @{} $Contexts $Diagnostics $true ($Depth + 1)
        }
    }
}

function Get-ProvenReadKeys($Contexts, $Diagnostics) {
    $keys = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($context in $Contexts.Values) {
        $body = $context.Body; $values = $context.Values; $types = $context.Types
        foreach ($call in (Get-ContextCalls $body)) {
            if ($call.Callee -notin @('get', 'contains') -or $call.Args.Count -lt 1) { continue }
            $inlineRequest = $call.InlineRequestReceiver -and $types[$call.InlineRequestReceiver] -eq 'Record "Message Argument ori"'
            if ($values[$call.Receiver] -ne 'request' -and -not $inlineRequest) { continue }
            $atCall = $values.Clone()
            foreach ($name in $context.Mutations.Keys) { if ($call.Index -gt $context.Mutations[$name]) { $atCall[$name] = '?' } }
            $key = Resolve-ContextValue $call.Args[0] $atCall $types
            if ($key -like 's:*') { [void]$keys.Add($key.Substring(2)) }
            else { [void]$Diagnostics.Add("$($context.Object)::$($context.Procedure): unresolved request key") }
        }
    }
    return ,$keys
}

function Get-DeclaredKeys($Objects, [string]$ContractCodeunit) {
    $keys = New-Object 'System.Collections.Generic.HashSet[string]'
    $seen = @{}
    Get-Reach $Objects $ContractCodeunit 'getparameters' $seen
    # A parameter declared only when a Boolean argument is true is not declared where the call passes false (#401).
    $falseFlags = Get-FalseFlags $Objects $seen
    if ($falseFlags.Count -gt 0) {
        $Objects = Get-PrunedObjects $Objects $falseFlags
        $seen = @{}
        Get-Reach $Objects $ContractCodeunit 'getparameters' $seen
    }
    $contexts = @{}
    Get-ContextReach $Objects $ContractCodeunit 'getparameters' @{} $contexts $script:AnalysisDiagnostics
    foreach ($context in $contexts.Values) {
        $calls = Get-ContextCalls $context.Body
        foreach ($call in $calls) {
            if ($call.Callee -ne 'parameter' -or $call.Args.Count -eq 0 -or $context.Types[$call.Receiver] -ne 'Codeunit "Msg Contract Mgt ori"') { continue }
            $value = Resolve-ContextValue $call.Args[0] $context.Values $context.Types
            if ($value -like 's:*') { [void]$keys.Add($value.Substring(2)); continue }
            # Preserve the bounded literal-list builder pattern, never arbitrary JSON.
            if ($call.Args[0] -match '^(\w+)\.Get\(') {
                $list = $Matches[1]
                $ranges = @($calls | Where-Object { $_.Receiver -eq $list -and $_.Callee -eq 'addrange' })
                if ($ranges.Count -gt 0) {
                    foreach ($range in $ranges) {
                        foreach ($arg in $range.Args) {
                            $item = Resolve-ContextValue $arg $context.Values $context.Types
                            if ($item -like 's:*') { [void]$keys.Add($item.Substring(2)) }
                            else { [void]$script:AnalysisDiagnostics.Add("$($context.Object)::$($context.Procedure): unresolved parameter list") }
                        }
                    }
                    continue
                }
            }
            [void]$script:AnalysisDiagnostics.Add("$($context.Object)::$($context.Procedure): unresolved parameter declaration")
        }
    }
    return ,$keys
}

function Add-TargetText([string]$Text, $Keys) {
    # A comma list declares each key; so does 'data.bankAccountNo + data.statementNo' (a pair). A nested key such as
    # forRecord.tableNo also declares tableNo, the name the code reads from the nested object (#431). The guard compares
    # names only, so a read of a top-level 'tableNo' passes as declared when only 'forRecord.tableNo' is. That is accepted:
    # the guard cannot tell which object a key is read from, and it only ever widens the declared side here (#590).
    foreach ($part in ($Text -split '[,+]')) {
        $key = $part.Trim()
        if ($key.StartsWith('data.')) { $key = $key.Substring(5) }
        if ($key -eq '') { continue }
        [void]$Keys.Add($key)
        if ($key.Contains('.')) { [void]$Keys.Add($key.Substring($key.LastIndexOf('.') + 1)) }
    }
}

# The keys under data that the target chapter names as identifiers (TargetEntry('data.orderNo', ...)). They are declared
# there, not in the parameters chapter. A comma-separated literal declares each key. A key built as 'data.' + Parameter
# declares the literal the caller passed for that parameter (PostedDocumentTarget's NumberKey / IdKey).
function Get-TargetKeys($Objects, [string]$ContractCodeunit) {
    $keys = New-Object 'System.Collections.Generic.HashSet[string]'
    $seen = @{}
    Get-Reach $Objects $ContractCodeunit 'gettarget' $seen
    $concatParam = [regex]::new("'data\.'\s*\+\s*(\w+)", 'IgnoreCase')
    $quotedFragment = [regex]::new("'([^']*)'")
    foreach ($entry in $seen.Keys) {
        $parts = $entry -split '::', 2
        $objectName = $parts[0]
        $procedureName = $parts[1]
        foreach ($body in $Objects[$objectName].Procedures[$procedureName]) {
            foreach ($m in $targetLiteral.Matches($body)) { Add-TargetText $m.Groups[1].Value $keys }
            $dynamic = @{}
            foreach ($m in $concatParam.Matches($body)) { $dynamic[$m.Groups[1].Value] = $true }
            if ($dynamic.Count -eq 0) { continue }
            foreach ($fragment in $quotedFragment.Matches($body)) {
                if ($fragment.Groups[1].Value -match 'data\.\w') { Add-TargetText $fragment.Groups[1].Value $keys }
            }
            $signature = [regex]::Match($body, '(?i)(?:procedure|trigger)\s+(?:"[^"]+"|\w+)\s*\(([^)]*)\)')
            if (-not $signature.Success) { continue }
            $paramNames = @()
            foreach ($param in $signature.Groups[1].Value.Split(';')) {
                $name = [regex]::Match($param, '(?i)(?:var\s+)?(\w+)\s*:')
                if ($name.Success) { $paramNames += $name.Groups[1].Value }
            }
            $escaped = [regex]::Escape($procedureName)
            $call = [regex]::new("\b$escaped\s*\(((?:'[^']*'\s*,?\s*)+)\)", 'IgnoreCase')
            foreach ($caller in $seen.Keys) {
                $callerParts = $caller -split '::', 2
                foreach ($callerBody in $Objects[$callerParts[0]].Procedures[$callerParts[1]]) {
                    foreach ($site in $call.Matches($callerBody)) {
                        $literals = @($stringLiteral.Matches($site.Groups[1].Value) | ForEach-Object { $_.Groups[1].Value })
                        for ($i = 0; $i -lt $paramNames.Count -and $i -lt $literals.Count; $i++) {
                            if ($dynamic.ContainsKey($paramNames[$i])) { [void]$keys.Add($literals[$i]) }
                        }
                    }
                }
            }
        }
    }
    return ,$keys
}

function Get-ReadKeys($Objects, [string]$Codeunit) {
    $contexts = @{}
    Get-ContextReach $Objects $Codeunit 'executebifrosttask' @{} $contexts $script:AnalysisDiagnostics $true
    return ,(Get-ProvenReadKeys $contexts $script:AnalysisDiagnostics)
}

function Find-Offenders([string]$AppFolder) {
    $objects = Read-Source (Join-Path $AppFolder 'src')
    $types = Get-Types $objects
    $found = New-Object 'System.Collections.Generic.List[string]'
    foreach ($typeName in $types.Keys) {
        $contractCodeunit = $types[$typeName].Contract
        $interfaceCodeunit = $types[$typeName].Interface
        if ($contractCodeunit -eq 'Default Contract ori') { continue }
        if (-not $objects.ContainsKey($contractCodeunit) -or -not $objects.ContainsKey($interfaceCodeunit)) {
            $found.Add("$typeName|unsupported-analysis|unavailable contract or implementation source")
            continue
        }
        if ($Explain -ne '' -and $typeName -ne $Explain) { continue }
        $script:AnalysisDiagnostics = New-Object 'System.Collections.Generic.HashSet[string]'
        $declared = Get-DeclaredKeys $objects $contractCodeunit
        $reads = Get-ReadKeys $objects $interfaceCodeunit
        $targetKeys = Get-TargetKeys $objects $contractCodeunit
        if ($Explain -ne '') {
            $script:Explained = $true
            Write-Host "contract codeunit : $contractCodeunit"
            Write-Host "interface codeunit: $interfaceCodeunit"
            Write-Host "declared          : $(($declared | Sort-Object) -join ', ')"
            Write-Host "target (data.)    : $(($targetKeys | Sort-Object) -join ', ')"
            Write-Host "read              : $(($reads | Sort-Object) -join ', ')"
        }
        foreach ($diagnostic in ($script:AnalysisDiagnostics | Sort-Object)) {
            if ($Explain -ne '') { Write-Host "unresolved        : $diagnostic" }
            $found.Add("$typeName|unsupported-analysis|$diagnostic")
        }
        foreach ($key in ($declared | Sort-Object)) {
            if (-not $reads.Contains($key)) { $found.Add("$typeName|declared-not-read|$key") }
        }
        foreach ($key in ($reads | Sort-Object)) {
            if ($script:NeverParameters -contains $key) { continue }
            if (-not $declared.Contains($key) -and -not $targetKeys.Contains($key)) { $found.Add("$typeName|read-not-declared|$key") }
        }
        # Coverage floor: a declared parameter with no detected read at all is a blind spot, not a pass (#430).
        if (($declared.Count -gt 0) -and ($reads.Count -eq 0)) { $found.Add("$typeName|no-reads-seen|*") }
    }
    return ,$found
}

function Read-AllowList([string]$Path) {
    $entries = New-Object 'System.Collections.Generic.List[string]'
    if (Test-Path -LiteralPath $Path) {
        foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
            $trimmed = $line.Trim()
            if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
            $parts = $trimmed.Split('|')
            # Coverage floor. The key is always *; a block that names another key is still this rule (#430).
            if ($parts.Count -eq 3 -and $parts[1] -eq 'no-reads-seen') {
                $entries.Add("$($parts[0])|no-reads-seen|*")
                continue
            }
            $entries.Add($trimmed)
        }
    }
    return ,$entries
}

function Compare-WithAllowList($Found, $Allowed) {
    # no-reads-seen|* is compared like every other rule: missing when the guard sees no reads is a failure,
    # and an entry whose type now has a detected read no longer applies and must be removed (#430).
    $problems = New-Object 'System.Collections.Generic.List[string]'
    foreach ($entry in $Found) {
        if ($entry -like '*|unsupported-analysis|*' -or -not $Allowed.Contains($entry)) { $problems.Add("New offender (fix the contract or the code, see #146, #357): $entry") }
    }
    foreach ($entry in $Allowed) {
        if (-not $Found.Contains($entry)) { $problems.Add("No longer applies, remove it from the allow-list: $entry") }
    }
    return ,$problems
}

function Invoke-SelfTest {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("contract-keys-" + [guid]::NewGuid().ToString('N'))
    $src = Join-Path $root 'app\src'
    New-Item -ItemType Directory -Path $src -Force | Out-Null
    try {
        @'
namespace Origo.Bifrost;
enum 1 "Message Type ori"
{
    value(1; "Sales.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Thing Impl ori", "Msg Contract ori" = "Thing Impl ori";
    }
    value(2; "Req.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Req Impl ori", "Msg Contract ori" = "Req Impl ori";
    }
    value(3; "Wrap.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Wrap Impl ori", "Msg Contract ori" = "Wrap Impl ori";
    }
    value(4; "Blind.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Blind Impl ori", "Msg Contract ori" = "Blind Impl ori";
    }
    value(5; "Delegate.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Delegate Impl ori", "Msg Contract ori" = "Delegate Impl ori";
    }
    value(6; "Rec.Thing.Set")
    {
        Implementation = "Msg Interface ori" = "Rec Impl ori", "Msg Contract ori" = "Rec Impl ori";
    }
    value(7; "Reader.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Reader Impl ori", "Msg Contract ori" = "Reader Impl ori";
    }
    value(8; "Cond.False.Get")
    {
        Implementation = "Msg Interface ori" = "Cond False Impl ori", "Msg Contract ori" = "Cond False Impl ori";
    }
    value(9; "Cond.True.Get")
    {
        Implementation = "Msg Interface ori" = "Cond True Impl ori", "Msg Contract ori" = "Cond True Impl ori";
    }
    value(10; "Text.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Text Impl ori", "Msg Contract ori" = "Text Impl ori";
    }
    value(11; "Const.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Const Impl ori", "Msg Contract ori" = "Const Impl ori";
    }
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Type.Enum.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 2 "Thing Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('customerNo', Token) then;
        if RequestJson.Get('undocumented', Token) then;
        if RequestJson.Get('b', Token) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('customerNo', 'string', true, 'The customer.'));
        Parameters.Add(ContractMgt.Parameter('renamed', 'string', false, 'Never read.'));
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.a, data.b, data.c', 'The keys.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Thing.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 3 "Req Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ReqJson: JsonObject;
        Take: Integer;
    begin
        ReqJson := Argument.GetRequestJson();
        if not Argument.TryReadInteger(ReqJson, 'pageSize', false, Take) then;
        if not Argument.TryReadInteger(ReqJson, 'reqExtra', false, Take) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('pageSize', 'integer', false, 'Page size.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Req.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 4 "Wrap Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Value: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        Value := GetTextParam(RequestJson, 'dateFilter', '');
        Value := GetTextParam(RequestJson, 'wrapExtra', '');
        ReadInside(RequestJson);
    end;

    local procedure GetTextParam(RequestJson: JsonObject; ParamName: Text; DefaultValue: Text): Text
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(ParamName, Token) then
            exit(Token.AsValue().AsText());
        exit(DefaultValue);
    end;

    local procedure ReadInside(Req: JsonObject)
    var
        Token: JsonToken;
    begin
        if Req.Get('insideKey', Token) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('dateFilter', 'string', false, 'The date filter.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Wrap.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 5 "Blind Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('silent', 'string', false, 'Never reached.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Blind.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 6 "Delegate Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
    begin
        RequestJson := Argument.GetRequestJson();
        Argument.EvaluateDelegated(RequestJson);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('delegatedKey', 'integer', false, 'Read inside the helper.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Delegate.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 8 "Rec Impl ori"
{
    // SelfTest case Rec.Thing.Set (#431): the records of the request data are read in a process codeunit that
    // takes the record object as its second argument.
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RecordsArray: JsonArray;
    begin
        if not Argument.GetRequestDataArray(RecordsArray) then
            exit;
        Codeunit.Run(Codeunit::"Rec Process ori", Argument);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'The record.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Rec.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 9 "Rec Process ori"
{
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        RecordsArray: JsonArray;
        RecordToken: JsonToken;
        RecordObject: JsonObject;
    begin
        Rec.GetRequestDataArray(RecordsArray);
        RecordsArray.Get(0, RecordToken);
        RecordObject := RecordToken.AsObject();
        ProcessRecord(Rec, RecordObject, 1);
    end;

    local procedure ProcessRecord(var Argument: Record "Message Argument ori"; Item: JsonObject; Index: Integer)
    var
        Token: JsonToken;
    begin
        if Item.Get('id', Token) then;
        if Item.Get('recExtra', Token) then;
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'RecProcess.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 10 "Reader Impl ori"
{
    // SelfTest case Reader.Thing.Get (#431): the table reader of Message Argument reads tableName for the type; a
    // GetRequestJson().Contains() read counts; the pair and the nested target keys are declared; any other
    // procedure of Message Argument is not a reader.
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
    begin
        RequestJson := Argument.GetRequestJson();
        Argument.GetTableIdFromRequestJson(RequestJson);
        Argument.FindSomethingElse(RequestJson);
        if Argument.GetRequestJson().Contains('inlineKey') then;
        if RequestJson.Get('pairA', Token) then;
        if RequestJson.Get('nestedKey', Token) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('tableName', 'string', false, 'The table.'));
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.pairA + data.pairB', 'The pair.'));
        Target.Add(ContractMgt.TargetEntry('data.forX.nestedKey', 'The nested key.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Reader.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 11 "Cond Parts ori"
{
    // SelfTest cases Cond.False.Get and Cond.True.Get (#401): extra and tail are declared only when the flag is true.
    procedure AddBase(var Parameters: JsonArray; WithExtra: Boolean; WithTail: Boolean)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('base', 'string', false, 'The base; it is always declared.'));
        if WithTail then begin
            // don't let this apostrophe confuse the scanner
            Parameters.Add(ContractMgt.Parameter('tail', 'string', false, 'Only with the tail; ends with end; and begin.'));
            Parameters.Add(ContractMgt.Parameter('tailTwo', 'string', false, 'Only with the tail, in the same block.'));
        end;
        if not WithExtra then
            exit;
        Parameters.Add(ContractMgt.Parameter('extra', 'string', false, 'Only with the extra.'));
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'CondParts.Codeunit.al') -Encoding UTF8
        foreach ($flag in @('False', 'True')) {
            $arguments = if ($flag -eq 'True') { 'true, true' } else { 'false, false' }
            $codeunitId = if ($flag -eq 'True') { 13 } else { 12 }
            @"
namespace Origo.Bifrost;
codeunit $codeunitId "Cond $flag Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('base', Token) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Cond Parts ori";
    begin
        Parts.AddBase(Parameters, $arguments);
        exit(true);
    end;
}
"@ | Set-Content -LiteralPath (Join-Path $src "Cond$flag.Codeunit.al") -Encoding UTF8
        }
        @'
namespace Origo.Bifrost;
codeunit 14 "Text Impl ori"
{
    // SelfTest case Text.Thing.Get (#459): a key that appears only in a translatable label or a message text is not a read.
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
        OnlyLbl: Label 'onlyInLabel';
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('anchor', Token) then;
        Error('onlyInLabel');
        Argument.AddError('code', 'text', 'onlyInError');
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('anchor', 'string', false, 'A real read, so the type is not blind.'));
        Parameters.Add(ContractMgt.Parameter('onlyInLabel', 'string', false, 'Only in a label and in Error.'));
        Parameters.Add(ContractMgt.Parameter('onlyInError', 'string', false, 'Only the parameter argument of AddError.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Text.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 15 "Const Impl ori"
{
    // SelfTest case Const.Thing.Get (#459): a Locked = true label in the reached procedure still names a key.
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
        KeyTok: Label 'constKey', Locked = true;
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('anchor', Token) then;
        ReadText(RequestJson, KeyTok);
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text)
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('anchor', 'string', false, 'A real read, so the type is not blind.'));
        Parameters.Add(ContractMgt.Parameter('constKey', 'string', false, 'Read through a locked label.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Const.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
table 7 "Message Argument ori"
{
    procedure TryReadInteger(RequestJson: JsonObject; ParameterName: Text; Required: Boolean; var Value: Integer): Boolean
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(ParameterName, Token) then begin
            Value := Token.AsValue().AsInteger();
            exit(true);
        end;
        exit(not Required);
    end;

    procedure GetTableIdFromRequestJson(RequestJson: JsonObject)
    var
        Token: JsonToken;
    begin
        if RequestJson.Get('tableName', Token) then;
        if RequestJson.Get('readerExtra', Token) then;
    end;

    procedure FindSomethingElse(RequestJson: JsonObject)
    var
        Token: JsonToken;
    begin
        if RequestJson.Get('notFollowed', Token) then;
    end;

    // SelfTest case Delegate.Thing.Get: Evaluate* forwards the request into TryEvaluate*, which forwards
    // the request JsonObject plus a literal key to an internal Try* helper. That key must count as a read.
    procedure EvaluateDelegated(RequestJson: JsonObject)
    begin
        TryEvaluateDelegated(RequestJson);
    end;

    procedure TryEvaluateDelegated(RequestJson: JsonObject)
    var
        Value: Integer;
    begin
        if not TryReadInteger(RequestJson, 'delegatedKey', false, Value) then;
        if not TryReadInteger(RequestJson, 'delegateExtra', false, Value) then;
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Argument.Table.al') -Encoding UTF8
        $found = Find-Offenders (Join-Path $root 'app')
        $expected = @(
            'Sales.Thing.Get|declared-not-read|renamed',
            'Sales.Thing.Get|read-not-declared|undocumented',
            'Req.Thing.Get|read-not-declared|reqExtra',
            'Wrap.Thing.Get|read-not-declared|wrapExtra',
            'Wrap.Thing.Get|read-not-declared|insideKey',
            'Blind.Thing.Get|declared-not-read|silent',
            'Blind.Thing.Get|no-reads-seen|*',
            'Delegate.Thing.Get|read-not-declared|delegateExtra',
            'Rec.Thing.Set|read-not-declared|recExtra',
            'Reader.Thing.Get|read-not-declared|inlineKey',
            'Reader.Thing.Get|read-not-declared|readerExtra',
            'Cond.True.Get|declared-not-read|extra',
            'Cond.True.Get|declared-not-read|tail',
            'Cond.True.Get|declared-not-read|tailTwo',
            'Text.Thing.Get|declared-not-read|onlyInLabel',
            'Text.Thing.Get|declared-not-read|onlyInError'
        )
        $absent = @(
            'Sales.Thing.Get|read-not-declared|b',
            'Sales.Thing.Get|read-not-declared|a, data.b, data.c',
            'Req.Thing.Get|read-not-declared|pageSize',
            'Req.Thing.Get|no-reads-seen|*',
            'Wrap.Thing.Get|read-not-declared|dateFilter',
            'Wrap.Thing.Get|no-reads-seen|*',
            'Delegate.Thing.Get|no-reads-seen|*',
            'Delegate.Thing.Get|declared-not-read|delegatedKey',
            'Delegate.Thing.Get|read-not-declared|delegatedKey',
            'Rec.Thing.Set|no-reads-seen|*',
            'Rec.Thing.Set|read-not-declared|id',
            'Reader.Thing.Get|no-reads-seen|*',
            'Reader.Thing.Get|read-not-declared|tableName',
            'Reader.Thing.Get|read-not-declared|pairA',
            'Reader.Thing.Get|read-not-declared|nestedKey',
            'Reader.Thing.Get|read-not-declared|notFollowed',
            'Cond.False.Get|declared-not-read|extra',
            'Cond.False.Get|declared-not-read|tail',
            'Cond.False.Get|declared-not-read|tailTwo',
            'Cond.False.Get|declared-not-read|base',
            'Cond.True.Get|declared-not-read|base',
            'Text.Thing.Get|declared-not-read|anchor',
            'Text.Thing.Get|no-reads-seen|*',
            'Const.Thing.Get|declared-not-read|constKey',
            'Const.Thing.Get|declared-not-read|anchor',
            'Const.Thing.Get|no-reads-seen|*'
        )
        $failed = $false
        foreach ($e in $expected) {
            if (-not $found.Contains($e)) { Write-Host "SelfTest FAILED: not reported: $e"; $failed = $true }
        }
        foreach ($e in $absent) {
            if ($found.Contains($e)) { Write-Host "SelfTest FAILED: reported but should not be: $e"; $failed = $true }
        }
        if ($found.Count -ne $expected.Count) { Write-Host "SelfTest FAILED: expected $($expected.Count) offenders, got $($found.Count): $($found -join '; ')"; $failed = $true }
        $listed = New-Object 'System.Collections.Generic.List[string]'
        foreach ($e in $expected) { $listed.Add($e) }
        if ((Compare-WithAllowList $found $listed).Count -ne 0) { Write-Host 'SelfTest FAILED: a fully allow-listed set must pass.'; $failed = $true }
        if ((Compare-WithAllowList $found (New-Object 'System.Collections.Generic.List[string]')).Count -ne $expected.Count) { Write-Host 'SelfTest FAILED: new offenders must be reported.'; $failed = $true }
        $stale = New-Object 'System.Collections.Generic.List[string]'
        foreach ($e in $expected) { $stale.Add($e) }
        $stale.Add('Sales.Thing.Get|declared-not-read|gone')
        if ((Compare-WithAllowList $found $stale).Count -ne 1) { Write-Host 'SelfTest FAILED: a stale allow-list entry must be reported.'; $failed = $true }
        $missingFloor = New-Object 'System.Collections.Generic.List[string]'
        foreach ($e in $expected) { if ($e -ne 'Blind.Thing.Get|no-reads-seen|*') { $missingFloor.Add($e) } }
        $missingProblems = Compare-WithAllowList $found $missingFloor
        if (($missingProblems | Where-Object { $_ -like '*Blind.Thing.Get|no-reads-seen|*' }).Count -ne 1) { Write-Host 'SelfTest FAILED: a type with no detected reads must fail when it is not allow-listed.'; $failed = $true }
        $staleFloor = New-Object 'System.Collections.Generic.List[string]'
        foreach ($e in $expected) { $staleFloor.Add($e) }
        $staleFloor.Add('Sales.Thing.Get|no-reads-seen|*')
        $staleFloorProblems = Compare-WithAllowList $found $staleFloor
        if (($staleFloorProblems | Where-Object { $_ -like '*Sales.Thing.Get|no-reads-seen|*' }).Count -ne 1) { Write-Host 'SelfTest FAILED: a no-reads-seen entry must fail once a read is detected.'; $failed = $true }
        if ($failed) { exit 1 }
        Write-Host 'SelfTest passed.'
    }
    finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# SelfTest for the conditional parameters (#590): a call the guard cannot read keeps a parameter declared, and the exit of
# 'if not Flag then exit;' inside a nested block cuts only that block. A second synthetic app keeps these cases apart.
function Invoke-SelfTestConditionalParameters {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("contract-keys-cond-" + [guid]::NewGuid().ToString('N'))
    $src = Join-Path $root 'app\src'
    New-Item -ItemType Directory -Path $src -Force | Out-Null
    try {
        @'
namespace Origo.Bifrost;
enum 1 "Message Type ori"
{
    value(1; "Veto.Unread.Get")
    {
        Implementation = "Msg Interface ori" = "Veto Unread Impl ori", "Msg Contract ori" = "Veto Unread Impl ori";
    }
    value(2; "Veto.Chain.Get")
    {
        Implementation = "Msg Interface ori" = "Veto Chain Impl ori", "Msg Contract ori" = "Veto Chain Impl ori";
    }
    value(3; "Veto.False.Get")
    {
        Implementation = "Msg Interface ori" = "Veto False Impl ori", "Msg Contract ori" = "Veto False Impl ori";
    }
    value(4; "Veto.Nested.Get")
    {
        Implementation = "Msg Interface ori" = "Veto Nested Impl ori", "Msg Contract ori" = "Veto Nested Impl ori";
    }
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Type.Enum.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 21 "Veto Parts ori"
{
    // extra is declared only when WithExtra is true.
    procedure AddBase(var Parameters: JsonArray; WithExtra: Boolean)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('base', 'string', false, 'The base; it is always declared.'));
        if WithExtra then
            Parameters.Add(ContractMgt.Parameter('extra', 'string', false, 'Only with the extra.'));
    end;

    // inner is declared only when WithInner is true; afterBlock is declared always, after the block that holds the exit.
    procedure AddNested(var Parameters: JsonArray; WithInner: Boolean)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('base', 'string', false, 'The base; it is always declared.'));
        if true then begin
            if not WithInner then
                exit;
            Parameters.Add(ContractMgt.Parameter('inner', 'string', false, 'Only with the inner; ends with end;'));
        end;
        Parameters.Add(ContractMgt.Parameter('afterBlock', 'string', false, 'Declared whatever the flag says.'));
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'VetoParts.Codeunit.al') -Encoding UTF8
        $calls = [ordered]@{
            'Unread' = @{ Id = 22; Body = "Parts.AddBase(Parameters, false);`n        Parts.AddBase(Parameters, Pick(1));" }
            'Chain'  = @{ Id = 23; Body = "Parts.AddBase(Parameters, false);`n        GetParts().AddBase(Parameters, true);" }
            'False'  = @{ Id = 24; Body = "Parts.AddBase(Parameters, false);" }
            'Nested' = @{ Id = 25; Body = "Parts.AddNested(Parameters, false);" }
        }
        foreach ($name in $calls.Keys) {
            $id = $calls[$name].Id
            $body = $calls[$name].Body
            @"
namespace Origo.Bifrost;
codeunit $id "Veto $name Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('base', Token) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Veto Parts ori";
    begin
        $body
        exit(true);
    end;
}
"@ | Set-Content -LiteralPath (Join-Path $src "Veto$name.Codeunit.al") -Encoding UTF8
        }
        $found = Find-Offenders (Join-Path $root 'app')
        $expected = @(
            'Veto.Unread.Get|declared-not-read|extra',
            'Veto.Chain.Get|declared-not-read|extra',
            'Veto.Chain.Get|unsupported-analysis|Veto Chain Impl ori::getparameters: unresolved chained addbase',
            'Veto.Nested.Get|declared-not-read|afterBlock'
        )
        $absent = @(
            'Veto.False.Get|declared-not-read|extra',
            'Veto.Nested.Get|declared-not-read|inner',
            'Veto.Unread.Get|declared-not-read|base',
            'Veto.Chain.Get|declared-not-read|base',
            'Veto.False.Get|declared-not-read|base',
            'Veto.Nested.Get|declared-not-read|base'
        )
        $failed = $false
        foreach ($e in $expected) {
            if (-not $found.Contains($e)) { Write-Host "SelfTest FAILED: not reported: $e"; $failed = $true }
        }
        foreach ($e in $absent) {
            if ($found.Contains($e)) { Write-Host "SelfTest FAILED: reported but should not be: $e"; $failed = $true }
        }
        if ($found.Count -ne $expected.Count) { Write-Host "SelfTest FAILED: expected $($expected.Count) offenders, got $($found.Count): $($found -join '; ')"; $failed = $true }
        if ($failed) { exit 1 }
        Write-Host 'SelfTest (conditional parameters) passed.'
    }
    finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($SelfTest) {
    Invoke-SelfTest
    Invoke-SelfTestConditionalParameters
    . (Join-Path $PSScriptRoot 'tests/ContractParameterKeys.Context.Tests.ps1')
    Invoke-ContextSelfTest
    exit 0
}

$found = Find-Offenders $AppFolder
# -Explain prints what the guard sees for one type. The other allow-list entries are not stale just because they were not printed (#430).
if ($Explain -ne '') {
    if (-not $script:Explained) {
        Write-Host "::error::No message type named '$Explain' with a contract was found. Use the name as the Message Type enum spells it, for example Data.Notes.Set."
        exit 1
    }
    exit 0
}
$allowed = Read-AllowList $AllowListPath
$problems = Compare-WithAllowList $found $allowed
if ($problems.Count -gt 0) {
    Write-Host "::error::The contract parameter names and the keys the code reads disagree ($($problems.Count) problem(s)). Fix the contract or the code; the allow-list may only shrink (#357)."
    $problems | ForEach-Object { Write-Host $_ }
    exit 1
}
Write-Host "Every contract parameter is a key the code reads, and every key the code reads is declared ($($allowed.Count) allow-listed)."
