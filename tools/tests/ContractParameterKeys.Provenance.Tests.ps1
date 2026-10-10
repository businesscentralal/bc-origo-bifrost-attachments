# Synthetic source proofs only: no compiler, package-signature or runtime claim.
function Invoke-ProvenanceSelfTest {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('contract-provenance-' + [guid]::NewGuid().ToString('N'))
    $src = Join-Path $root 'src'; New-Item -ItemType Directory $src -Force | Out-Null
    function Check($Value, [string]$Message) { $script:ProvenanceChecks++; if (-not $Value) { throw "Provenance selftest FAILED: $Message" } }
    $script:ProvenanceChecks = 0
    function Fixture([string]$Execute, [string]$Helper = '', [string]$Extra = '', [string]$Locals = '') {
        Get-ChildItem $src -Filter '*.al' | Remove-Item -Force
        @'
enum 1 "Message Type ori"
{
    value(1; "Proof.Get")
    {
        Implementation = "Msg Interface ori" = "Proof ori", "Msg Contract ori" = "Proof ori";
    }
}
'@ | Set-Content (Join-Path $src 'Type.al')
        @"
codeunit 2 "Proof ori"
{
    TableNo = "Message Argument ori";
    procedure GetParameters() Parameters: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('key', 'string', false, 'Key.'));
    end;
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
        Reader: Codeunit "Reader ori";
        $Locals
    begin
        $Execute
    end;
    $Extra
}
"@ | Set-Content (Join-Path $src 'Proof.al')
        if ($Helper) { $Helper | Set-Content (Join-Path $src 'Reader.al') }
    }
    function Clean([string]$Name) {
        $f = Find-Offenders $root; Check ($f.Count -eq 0) "$Name : $($f -join '; ')"
    }
    function Fails([string]$Name, [string]$Expected = 'declared-not-read|key') {
        $f = Find-Offenders $root
        Check ($f.Count -gt 0) "$Name must fail"
        Check (@($f | Where-Object { $_ -like "Proof.Get|$Expected" }).Count -gt 0) "$Name missing $Expected : $($f -join '; ')"
    }
    function Reject([scriptblock]$Action, [string]$Expected) {
        $errorText = ''
        try { & $Action } catch { $errorText = $_.Exception.Message }
        Check ($errorText -like "*$Expected*") "Expected rejection $Expected, got $errorText"
    }
    $leaf = @'
codeunit 3 "Reader ori"
{
    procedure Load(var Argument: Record "Message Argument ori"; var Payload: JsonObject)
    begin
        Payload := Argument.GetRequestJson();
    end;
}
'@
    $wrapper = @'
codeunit 3 "Reader ori"
{
    procedure Load(var Argument: Record "Message Argument ori"; var Payload: JsonObject): Boolean
    begin
        Clear(Payload);
        if Acquire(Argument, Payload) then
            exit(true);
        Argument.AddError('invalid data');
        exit(false);
    end;
    [TryFunction]
    local procedure Acquire(var Argument: Record "Message Argument ori"; var Output: JsonObject)
    begin
        Output := Argument.GetRequestJson();
    end;
}
'@
    $read = "if RequestJson.Get('key', Token) then;"
    $onrun = @'
    trigger OnRun()
    var
        Reader: Codeunit "Reader ori";
        RequestJson: JsonObject;
        Token: JsonToken;
    begin
        if Reader.Load(Rec, RequestJson) then
            if RequestJson.Get('key', Token) then;
    end;
'@
    try {
        Fixture "Reader.Load(Argument, RequestJson); $read" $leaf
        Clean 'unconditional var output'
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" $wrapper
        Clean 'TryFunction output through Boolean success wrapper'
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" ($wrapper.Replace('Acquire(Argument, Payload)', 'Acquire(Payload, Argument)').Replace('var Argument: Record "Message Argument ori"; var Output: JsonObject', 'var Output: JsonObject; var Argument: Record "Message Argument ori"'))
        Clean 'reordered output formal propagation'
        Fixture 'Codeunit.Run(Codeunit::"Proof ori", Argument);' $wrapper $onrun
        Clean 'self Codeunit.Run enters typed OnRun with output proof'
        Fixture 'Codeunit.Run(Codeunit::"Missing ori", Argument);' $wrapper $onrun
        Fails 'missing dispatch target' 'unsupported-analysis|*incompatible Codeunit.Run source'
        Fixture 'Codeunit.Run(ChooseCodeunit(), Argument);' $wrapper $onrun
        Fails 'dynamic dispatch' 'unsupported-analysis|*unsupported Codeunit.Run dispatch'
        Fixture 'Codeunit.Run(Codeunit::"Proof ori", RequestJson);' $wrapper $onrun
        Fails 'wrong dispatch argument' 'unsupported-analysis|*unsupported Codeunit.Run dispatch'
        Fixture 'Codeunit.Run(Codeunit::"Proof ori", Argument);' $wrapper
        Fails 'missing OnRun' 'unsupported-analysis|*unavailable source'
        Fixture "Reader.Load(Argument, RequestJson); $read" $wrapper
        Fails 'unchecked success wrapper cannot bind output'
        Fixture "if Reader.Load(Argument, RequestJson) then; $read" $wrapper
        Fails 'output read outside success branch'
        Fixture "if not Reader.Load(Argument, RequestJson) then begin $read end;" $wrapper
        Fails 'failure branch cannot bind output'
        Fixture "if Reader.Load(Argument, RequestJson) or OtherCondition() then begin $read end;" $wrapper
        Fails 'compound success condition unsupported'
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" ($wrapper.Replace('Output := Argument.GetRequestJson();', "Message('key');"))
        Fails 'removed actual acquisition'
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" ($wrapper.Replace('Output := Argument.GetRequestJson();', 'Output := Unknown.GetRequestJson();'))
        Fails 'wrong acquisition source'
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" ($wrapper.Replace('Output := Argument.GetRequestJson();', 'if Condition() then Output := Argument.GetRequestJson();'))
        Fails 'conditional acquisition unsupported'
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" ($wrapper.Replace('Output := Argument.GetRequestJson();', 'Output := Argument.GetRequestJson(); Clear(Output);'))
        Fails 'cleared producer output'
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" ($wrapper.Replace('Output := Argument.GetRequestJson();', 'Output := Argument.GetRequestJson(); Output := Other();'))
        Fails 'overwritten producer output'
        Fixture "if Reader.Load(Argument, RequestJson) then begin Clear(RequestJson); $read end;" $wrapper
        Fails 'cleared consumer output'
        Fixture "if Reader.Load(Argument, RequestJson) then begin RequestJson := Other(); $read end;" $wrapper
        Fails 'overwritten consumer output'
        Fixture "if Reader.Load(Argument, RequestJson) then begin RequestJson.Add('key', 'fake'); $read end;" $wrapper
        Fails 'mutated consumer output'
        Fixture "if Reader.Load(Argument, RequestJson) then begin Unknown(RequestJson); $read end;" $wrapper
        Fails 'unknown call with consumer output'
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" ($wrapper.Replace('exit(false);', 'exit(true);'))
        Fails 'unproven alternate success'
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" ($wrapper.Replace('local procedure Acquire', 'local procedure MissingAcquire'))
        Fails 'unavailable forwarded output'
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" ($wrapper.Replace('Output := Argument.GetRequestJson();', 'Acquire(Argument, Output);'))
        Fails 'recursive output cannot prove provenance'
        Fixture "while Condition() do begin Reader.Load(Argument, RequestJson); $read end;" $leaf
        Fails 'unsupported output loop' 'unsupported-analysis|*unsupported output control flow'
        Fixture "$read Reader.Load(Argument, RequestJson);" $leaf
        Fails 'read precedes acquisition'
        Fixture "Reader.Load(Argument, RequestJson); $read" ($leaf.Replace('procedure Load', '[TryFunction]' + "`n    procedure Load"))
        Fails 'unguarded TryFunction output'
        Fixture "if Condition() then Reader.Load(Argument, RequestJson); $read" $leaf
        Fails 'unconditional producer in conditional branch cannot leak'
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" ($wrapper.Replace('Output := Argument.GetRequestJson();', 'Output := Argument.GetRequestJson();') + $leaf)
        Fails 'ambiguous output overloads' 'unsupported-analysis|*unresolved overload'
        $mutator = $leaf.Replace('    procedure Load', @'
    procedure Change(Input: JsonObject)
    begin
        Input.Remove('key');
    end;
    procedure Load
'@)
        Fixture "Reader.Load(Argument, RequestJson); Reader.Change(RequestJson); $read" $mutator
        Fails 'by-value JsonObject reference mutation'
        Fixture "RequestJson := Argument.GetRequestJson(); Reader.Change(RequestJson); $read" $mutator
        Fails 'ordinary request reference mutation'
        Fixture "RequestJson := Argument.GetRequestJson(); RequestJson.Remove('key'); $read"
        Fails 'ordinary request member mutation'
        $aliasMutation = $mutator.Replace("Input.Remove('key');", "Alias := Input; Alias.Remove('key');")
        Fixture "Reader.Load(Argument, RequestJson); Reader.Change(RequestJson); $read" $aliasMutation
        Fails 'aliased reference mutation'
        $readonly = $mutator.Replace("Input.Remove('key');", "if Input.Contains('key') then;")
        Fixture 'Reader.Load(Argument, RequestJson); Reader.Change(RequestJson);' $readonly
        Clean 'source-proven readonly forwarding of output'
        Fixture 'Codeunit.Run(Codeunit::"Proof ori");' $wrapper $onrun
        Fails 'recordless dispatch cannot prove request' 'unsupported-analysis|*unsupported Codeunit.Run dispatch'
        Fixture "Reader.Load(Argument, RequestJson); $read" ($leaf.Replace('procedure Load', '[TryFunction] procedure Load'))
        Fails 'inline TryFunction attribute cannot be ignored'
        Fixture "Reader.Load(Argument, RequestJson); $read" ($leaf.Replace('procedure Load', '[TryFunction]' + "`n`n    // Attribute retains meaning across trivia.`n    procedure Load"))
        Fails 'TryFunction attribute across comments cannot be ignored'
        $chain = "codeunit 3 `"Reader ori`"`n{`n"
        for ($i = 0; $i -lt 18; $i++) {
            $name = if ($i -eq 0) { 'Load' } else { "Forward$i" }
            $next = $i + 1
            $chain += "    procedure $name(var Argument: Record `"Message Argument ori`"; var Payload: JsonObject)`n    begin`n        Forward$next(Argument, Payload);`n    end;`n"
        }
        $chain += "    procedure Forward18(var Argument: Record `"Message Argument ori`"; var Payload: JsonObject)`n    begin`n        Payload := Argument.GetRequestJson();`n    end;`n}`n"
        Fixture "Reader.Load(Argument, RequestJson); $read" $chain
        Fails 'natural forwarding chain over budget does not prove output'
        # Explicit budget checks prove bounded failure, not a shortened test depth default.
        Fixture '' $leaf
        $objects = Read-Source $src
        Check ($null -eq (Get-RequestOutputProof $objects 'Reader ori' 'load' 1 @{ Count = 256; Active = @{} })) 'output context budget fails closed'
        Check ($null -eq (Get-RequestOutputProof $objects 'Reader ori' 'load' 1 @{ Count = 0; Active = @{} } 17)) 'output depth budget fails closed'
        $contexts = @{}; $diagnostics = [Collections.Generic.HashSet[string]]::new()
        Get-ContextReach $objects 'Proof ori' 'executebifrosttask' @{} $contexts $diagnostics $true 41
        Check ($diagnostics.Contains('Proof ori::executebifrosttask: traversal bound')) 'read depth bound retained'
        for ($i = 0; $i -le 2000; $i++) { $contexts["$i"] = $true }
        Get-ContextReach $objects 'Proof ori' 'executebifrosttask' @{} $contexts $diagnostics $true
        Check ($contexts.Count -eq 2001) 'context bound does not add proof'

        # A separate source file is never discovered recursively from an external folder.
        $external = Join-Path $root 'External.al'
        $source = @'
namespace Proof.Dependency;
table 123 "Message Argument ori"
{
    procedure EvaluateKey(Request: JsonObject)
    var
        Token: JsonToken;
    begin
        if Request.Get('key', Token) then;
    end;
}
'@
        [IO.File]::WriteAllText($external, $source)
        $bytes = [IO.File]::ReadAllBytes($external)
        $dependency = @{ id = '7505e808-6e52-4b96-a328-82573391297a'; name = 'Fixture Dependency'; publisher = 'Fixture'; version = '1.0.0.0' }
        @{ dependencies = @($dependency) } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $root 'app.json')
        $m = @{ schemaVersion = 1; repo = 'Fixture/Dependency'; sourceSha = ('1' * 40); repositoryPath = 'app/src/Argument.al'; blob = [Convert]::ToHexString([Security.Cryptography.SHA1]::HashData([byte[]]([Text.Encoding]::UTF8.GetBytes("blob $($bytes.Length)`0") + $bytes))).ToLowerInvariant(); sha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant(); sharedPath = $external; objectKind = 'table'; objectName = 'Message Argument ori'; objectId = 123; namespace = 'Proof.Dependency'; dependency = $dependency }
        $manifest = Join-Path $root 'source.json'
        function Save-Manifest($Value) { $Value | ConvertTo-Json -Depth 5 | Set-Content $manifest; return (Get-FileHash $manifest -Algorithm SHA256).Hash }
        $pin = Save-Manifest $m
        Fixture "RequestJson := Argument.GetRequestJson(); Argument.EvaluateKey(RequestJson);"
        Fails 'dependency unavailable by default' 'unsupported-analysis|*unavailable source'
        $script:DependencySourceManifest = $manifest; $script:DependencySourceManifestSha256 = $pin
        Clean 'pinned external read with exact object and source identity'
        # Keep the same trusted manifest while changing bytes or immutable source identity.
        [IO.File]::WriteAllText($external, $source.Replace("'key'", "'fake'"))
        Reject { Find-Offenders $root } 'source SHA256 mismatch'
        [IO.File]::WriteAllText($external, $source)
        $altered = $m.Clone(); $altered.sourceSha = '2' * 40; $null = Save-Manifest $altered
        Reject { Find-Offenders $root } 'manifest SHA256 mismatch'
        foreach ($change in @(
            @{ Key = 'blob'; Value = ('0' * 40); Error = 'Git blob mismatch' },
            @{ Key = 'objectName'; Value = 'Wrong ori'; Error = 'AL object identity mismatch' },
            @{ Key = 'objectId'; Value = 999; Error = 'AL object identity mismatch' },
            @{ Key = 'namespace'; Value = 'Wrong.Namespace'; Error = 'AL object identity mismatch' },
            @{ Key = 'repositoryPath'; Value = 'app/src/../Argument.al'; Error = 'Unsupported dependency source identity' },
            @{ Key = 'sourceSha'; Value = 'main'; Error = 'Unsupported dependency source identity' },
            @{ Key = 'dependency'; Value = @{ id = 'wrong' }; Error = 'Dependency app identity mismatch' }
        )) {
            $altered = $m.Clone(); $altered[$change.Key] = $change.Value
            $script:DependencySourceManifestSha256 = Save-Manifest $altered
            Reject { Find-Offenders $root } $change.Error
        }
        $script:DependencySourceManifestSha256 = Save-Manifest $m
        [IO.File]::WriteAllText($external, (' ' * 2097153))
        Reject { Find-Offenders $root } 'source size bound'
        [IO.File]::WriteAllText($external, $source)
        $script:DependencySourceManifestSha256 = ''
        Reject { Find-Offenders $root } 'independently pinned SHA256'
        $script:DependencySourceManifestSha256 = $pin
        [IO.File]::WriteAllText($manifest, (' ' * 65537))
        Reject { Find-Offenders $root } 'manifest size bound'
        $script:DependencySourceManifestSha256 = Save-Manifest $m
        $source | Set-Content (Join-Path $src 'Duplicate.al')
        Reject { Find-Offenders $root } 'Ambiguous dependency source object'
        Write-Host "Submitted provenance assertions retained: $script:ProvenanceChecks."
        $script:DependencySourceManifest = ''; $script:DependencySourceManifestSha256 = ''
        $priorChecks = $script:ProvenanceChecks
        $locals = 'Alias: JsonObject; OtherAlias: JsonObject;'
        # Fail closed at alias creation, even when the subsequent use is read-only
        # or the alias is reassigned. Paired direct/read-only controls stay valid.
        foreach ($tail in @(
            "Alias.Remove('key');",
            "OtherAlias := Alias; OtherAlias.Remove('key');",
            'Clear(Alias);',
            'Reader.Change(Alias);',
            'Unknown(Alias);',
            "if Alias.Contains('key') then;",
            "Alias := Other(); Alias.Remove('key');"
        )) {
            Fixture "Reader.Load(Argument, RequestJson); Alias := RequestJson; $tail $read" $mutator '' $locals
            Fails "caller-local alias rejected: $tail" 'unsupported-analysis|*unsupported output request alias assignment*'
        }
        Fixture "if Reader.Load(Argument, RequestJson) then begin Alias := RequestJson; Alias.Remove('key'); $read end;" $wrapper '' $locals
        Fails 'guarded output does not permit reference escape' 'unsupported-analysis|*unsupported output request alias assignment*'
        Fixture "Reader.Load(Argument, RequestJson); Alias := /* reference across trivia */ (RequestJson); Alias.Remove('key'); $read" $leaf '' $locals
        Fails 'parenthesized output alias across trivia rejected' 'unsupported-analysis|*unsupported output request alias assignment*'
        Fixture "Reader.Load(Argument, RequestJson); $read" $leaf
        Clean 'paired direct output read remains proven'
        Fixture "Reader.Load(Argument, RequestJson); Reader.Change(RequestJson); $read" $readonly
        Clean 'paired read-only output forwarding remains proven'
        Fixture "Alias := Other(); Reader.Load(Argument, RequestJson); Alias.Remove('key'); $read" $leaf '' $locals
        Clean 'unrelated preexisting JSON does not invalidate output'
        Fixture "Alias := RequestJson; Reader.Load(Argument, RequestJson); Alias.Remove('key'); $read" $leaf '' $locals
        Clean 'alias preceding unconditional output rebind is separate'

        $forwarder = @'
codeunit 3 "Reader ori"
{
    [TryFunction]
    procedure Load(var Argument: Record "Message Argument ori"; var Payload: JsonObject)
    begin
        Acquire(Argument, Payload);
    end;
    local procedure Acquire(var Argument: Record "Message Argument ori"; var Payload: JsonObject)
    begin
        Payload := Argument.GetRequestJson();
    end;
}
'@
        foreach ($attribute in @('[TryFunction]', '[TryFunction] /* keeps attribute across trivia */', ('[TryFunction]' + "`n    /* multiline`n       trivia */"), ('[TryFunction]' + "`n    // line comment trivia"))) {
            $producer = $forwarder.Replace('[TryFunction]', $attribute)
            Fixture "Reader.Load(Argument, RequestJson); $read" $producer
            Fails "unchecked outer forwarding TryFunction [$attribute]"
            Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" $producer
            Clean 'checked outer forwarding TryFunction'
            Fixture "if Reader.Load(Argument, RequestJson) then; $read" $producer
            Fails 'checked forwarding TryFunction cannot leak past success branch'
        }
        Fixture "Reader.Load(Argument, RequestJson); $read" ($forwarder.Replace('[TryFunction]', '/* [TryFunction] */'))
        Clean 'commented attribute does not make producer fallible'
        $multi = $forwarder.Replace('Acquire(Argument, Payload);', 'Middle(Argument, Payload);').Replace('    local procedure Acquire', @'
    local procedure Middle(var Argument: Record "Message Argument ori"; var Payload: JsonObject)
    begin
        Acquire(Argument, Payload);
    end;
    local procedure Acquire
'@)
        Fixture "Reader.Load(Argument, RequestJson); $read" $multi
        Fails 'unchecked outer TryFunction through two nontry hops'
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" $multi
        Clean 'checked outer TryFunction through two nontry hops'
        $innerTry = $multi.Replace('    local procedure Middle', '    [TryFunction] local procedure Middle')
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" $innerTry
        Fails 'checked outer TryFunction cannot hide unchecked inner TryFunction'
        $safeInner = $innerTry.Replace('        Middle(Argument, Payload);', @'
        if Middle(Argument, Payload) then
            exit(true);
        exit(false);
'@).Replace('procedure Load(var Argument: Record "Message Argument ori"; var Payload: JsonObject)', 'procedure Load(var Argument: Record "Message Argument ori"; var Payload: JsonObject): Boolean')
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" $safeInner
        Clean 'every fallible forwarding hop guarded'
        Fixture "Reader.Load(Argument, RequestJson); $read" $safeInner
        Fails 'guarded inner hop still requires outer success'
        $leafTry = $safeInner.Replace('    local procedure Acquire', '    [TryFunction] local procedure Acquire')
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" $leafTry
        Fails 'unchecked deepest TryFunction not hidden by checked outer hops'
        $safeLeaf = $leafTry.Replace('        Acquire(Argument, Payload);', @'
        if Acquire(Argument, Payload) then
            exit(true);
        exit(false);
'@).Replace('procedure Middle(var Argument: Record "Message Argument ori"; var Payload: JsonObject)', 'procedure Middle(var Argument: Record "Message Argument ori"; var Payload: JsonObject): Boolean')
        Fixture "if Reader.Load(Argument, RequestJson) then begin $read end;" $safeLeaf
        Clean 'all three TryFunction hops explicitly guarded'
        Write-Host "Correction regression assertions passed: $($script:ProvenanceChecks - $priorChecks)."
        Write-Host "SelfTest (output/source provenance) passed: $script:ProvenanceChecks assertions."
    } finally {
        $script:DependencySourceManifest = ''; $script:DependencySourceManifestSha256 = ''
        Remove-Item $root -Recurse -Force
    }
}
