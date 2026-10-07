# Loaded by Test-ContractParameterKeys.ps1 -SelfTest. These are source-analysis
# fixtures, not compiled AL/runtime evidence. Every negative case asserts failure.
function Invoke-ContextSelfTest {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('contract-context-' + [guid]::NewGuid().ToString('N'))
    $src = Join-Path $root 'src'
    New-Item -ItemType Directory -Path $src -Force | Out-Null
    $script:ContextChecks = 0
    $script:ContextScenarios = 0
    function Assert-Context($Condition, [string]$Message) {
        $script:ContextChecks++
        if (-not $Condition) { throw "Context selftest FAILED: $Message" }
    }
    function Set-Fixture([string]$Contract, [string]$Execute, [string]$Helpers = '', [string]$LocalVars = '') {
        Remove-Item (Join-Path $src '*.al') -Force
        @'
enum 1 "Message Type ori"
{
    value(1; "Fixture.Get")
    {
        Implementation = "Msg Interface ori" = "Fixture ori", "Msg Contract ori" = "Fixture ori";
    }
}
'@ | Set-Content (Join-Path $src 'Type.al')
        @"
codeunit 2 "Fixture ori"
{
    procedure GetParameters() Parameters: JsonArray
    var
        Parts: Codeunit "Parts ori";
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Selector: Text;
    begin
        $Contract
    end;
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        AliasJson: JsonObject;
        Token: JsonToken;
        Reader: Codeunit "Reader ori";
        Name: Text;
        $LocalVars
    begin
        RequestJson := Argument.GetRequestJson();
        $Execute
    end;
}
"@ | Set-Content (Join-Path $src 'Fixture.al')
        if ($Helpers) { $Helpers | Set-Content (Join-Path $src 'Helper.al') }
    }
    function Get-FixtureFindings {
        $script:ContextScenarios++
        $files = @(Get-ChildItem $src -Filter '*.al' | Sort-Object Name | ForEach-Object { $_.Name + ':' + (Get-FileHash $_.FullName -Algorithm SHA256).Hash })
        $bytes = [Text.Encoding]::UTF8.GetBytes(($files -join "`n"))
        $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
        $found = Find-Offenders $root
        Write-Host "Context fixture $script:ContextScenarios SHA256=$hash findings=$($found.Count)"
        return ,$found
    }
    function Assert-Clean([string]$Name) {
        $found = Get-FixtureFindings
        Assert-Context ($found.Count -eq 0) "$Name should pass: $($found -join '; ')"
    }
    function Assert-Failure([string]$Name, [string[]]$Expected) {
        $found = Get-FixtureFindings
        Assert-Context ($found.Count -gt 0) "$Name must fail"
        foreach ($entry in $Expected) { Assert-Context ($found.Contains("Fixture.Get|$entry")) "$Name missing $entry; got $($found -join '; ')" }
    }
    $declareKey = "Parameters.Add(ContractMgt.Parameter('key', 'string', false, 'A key.'));"
    $readKey = "if RequestJson.Get('key', Token) then;"
    $reader = @'
codeunit 3 "Reader ori"
{
    procedure ReadText(var Argument: Record "Message Argument ori"; Payload: JsonObject; KeyName: Text)
    var
        Token: JsonToken;
    begin
        if Payload.Get(KeyName, Token) then;
    end;
    procedure NeverCalled(Payload: JsonObject)
    var
        Token: JsonToken;
    begin
        if Payload.Get('unreached', Token) then;
    end;
}
'@
    $parts = @'
codeunit 4 "Parts ori"
{
    procedure GetParameters(Selector: Text) Parameters: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if Selector in ['Empty', 'OtherEmpty'] then
            exit;
        if not (Selector in ['A', 'B']) then
            Parameters.Add(ContractMgt.Parameter('other', 'string', false, 'Other.'));
        case Selector of
            'A', 'A2':
                begin
                    if Selector = 'A' then
                        Parameters.Add(ContractMgt.Parameter('a', 'string', false, 'A.'))
                    else
                        Parameters.Add(ContractMgt.Parameter('a2', 'string', false, 'A2.'));
                end;
            'B':
                Parameters.Add(ContractMgt.Parameter('b', 'string', false, 'B.'));
            else
                Parameters.Add(ContractMgt.Parameter('fallback', 'string', false, 'Fallback.'));
        end;
        if Selector <> 'A' then
            if Selector not in ['B', 'A2'] then
                exit;
        if Selector = 'A' then
            exit;
        Parameters.Add(ContractMgt.Parameter('tail', 'string', false, 'Tail.'));
    end;
}
'@
    try {
        Set-Fixture "exit(Parts.GetParameters('Empty'));" '' $parts
        Assert-Clean 'empty IN early exit'
        Set-Fixture "exit(Parts.GetParameters('A'));" "if RequestJson.Get('a', Token) then;" $parts
        Assert-Clean 'equality, case alternatives, nested else, early exit'
        Set-Fixture "exit(Parts.GetParameters('B'));" "if RequestJson.Get('b', Token) then; if RequestJson.Get('tail', Token) then;" $parts
        Assert-Clean 'second literal context'
        Set-Fixture "Parts.GetParameters('A'); Parts.GetParameters('B');" "if RequestJson.Get('a', Token) then; if RequestJson.Get('b', Token) then; if RequestJson.Get('tail', Token) then;" $parts
        Assert-Clean 'distinct contexts of same callee in one traversal'
        Set-Fixture "exit(Parts.GetParameters('A2'));" "if RequestJson.Get('other', Token) then; if RequestJson.Get('a2', Token) then; if RequestJson.Get('tail', Token) then;" $parts
        Assert-Clean 'literal NOT IN and nested else'
        Set-Fixture "exit(Parts.GetParameters('Z'));" "if RequestJson.Get('other', Token) then; if RequestJson.Get('fallback', Token) then;" $parts
        Assert-Clean 'case else and inequality early exit'
        Set-Fixture "Selector := 'A'; exit(Parts.GetParameters(Selector));" "if RequestJson.Get('a', Token) then;" $parts
        Assert-Clean 'constant local selector alias'
        Set-Fixture "exit(Parts.GetParameters(Selector));" '' $parts
        Assert-Failure 'dynamic selector' @('unsupported-analysis|Parts ori::getparameters: unresolved Text selector selector', 'declared-not-read|a', 'declared-not-read|b', 'no-reads-seen|*')
        $mutable = $parts.Replace("        if Selector in", "        Selector := Pick();`n        if Selector in")
        Set-Fixture "exit(Parts.GetParameters('Empty'));" '' $mutable
        Assert-Failure 'mutated formal selector' @('unsupported-analysis|Parts ori::getparameters: unresolved Text selector selector', 'declared-not-read|a')
        Set-Fixture "Selector := 'Empty'; Selector := Pick(); exit(Parts.GetParameters(Selector));" '' $parts
        Assert-Failure 'conflicting local assignments' @('unsupported-analysis|Parts ori::getparameters: unresolved Text selector selector', 'declared-not-read|a')
        Set-Fixture $declareKey "Reader.ReadText(Argument, RequestJson, 'key');" $reader
        Assert-Clean 'request second and key third; unreachable helper excluded'
        Set-Fixture $declareKey "AliasJson := RequestJson; Name := 'key'; Reader.ReadText(Argument, AliasJson, Name);" $reader
        Assert-Clean 'proven request and key aliases'
        $forward = $reader.Replace("        if Payload.Get(KeyName, Token) then;", "        Forward(KeyName, Payload);")
        $forward = $forward.Replace('    procedure NeverCalled', @'
    local procedure Forward(Name: Text; Request: JsonObject)
    var
        Token: JsonToken;
    begin
        if Request.Get(Name, Token) then;
    end;
    procedure NeverCalled
'@)
        Set-Fixture $declareKey "Reader.ReadText(Argument, RequestJson, 'key');" $forward
        Assert-Clean 'forwarding with reordered typed formals'
        Set-Fixture $declareKey "Reader.ReadText(Argument, RequestJson, 'key'); Reader.ReadText(Argument, RequestJson, 'extra');" $reader
        Assert-Failure 'undeclared typed-helper read' @('read-not-declared|extra')
        $removed = $reader.Replace('if Payload.Get(KeyName, Token) then;', "Message('key');")
        Set-Fixture $declareKey "Reader.ReadText(Argument, RequestJson, 'key');" $removed
        Assert-Failure 'removed actual read, nearby literal and unreachable helper' @('declared-not-read|key', 'no-reads-seen|*')
        Set-Fixture $declareKey "Reader.ReadText(Argument, RequestJson, 'key');"
        Assert-Failure 'missing helper source' @('unsupported-analysis|Reader ori::readtext: unavailable source', 'declared-not-read|key', 'no-reads-seen|*')
        Set-Fixture $declareKey "Unknown.Read(RequestJson, 'key');"
        Assert-Failure 'unresolved receiver' @('declared-not-read|key', 'no-reads-seen|*')
        Set-Fixture $declareKey "Reader.ReadText(Argument, RequestJson, Name);" $reader
        Assert-Failure 'unknown dynamic key' @('unsupported-analysis|Reader ori::readtext: unresolved request key', 'declared-not-read|key')
        Set-Fixture $declareKey "AliasJson := RequestJson; AliasJson := Other(); Reader.ReadText(Argument, AliasJson, 'key');" $reader
        Assert-Failure 'request alias overwritten' @('declared-not-read|key', 'no-reads-seen|*')
        Set-Fixture $declareKey "Name := 'key'; Name := Pick(); Reader.ReadText(Argument, RequestJson, Name);" $reader
        Assert-Failure 'key alias overwritten' @('declared-not-read|key', 'no-reads-seen|*')
        $overload = $reader.Replace('    procedure NeverCalled', @'
    procedure ReadText(var Argument: Record "Message Argument ori"; Payload: JsonObject; KeyName: Code[20])
    var
        Token: JsonToken;
    begin
        if Payload.Get(KeyName, Token) then;
    end;
    procedure NeverCalled
'@)
        Set-Fixture $declareKey "Reader.ReadText(Argument, RequestJson, 'key');" $overload
        Assert-Failure 'unresolved overloads' @('unsupported-analysis|Reader ori::readtext: unresolved overload', 'declared-not-read|key', 'no-reads-seen|*')
        Set-Fixture $declareKey "Reader.ReadText(Argument, RequestJson, 'key');" $reader 'Reader: Interface "Reader interface ori";'
        Assert-Failure 'ambiguous interface dispatch' @('declared-not-read|key', 'no-reads-seen|*')
        Set-Fixture '' "Reader.ReadText(Argument, RequestJson, 'description');" $reader
        Assert-Failure 'real missing description declaration' @('read-not-declared|description')
        Set-Fixture $declareKey "Message('RequestJson.Get(''key'', Token)');"
        Assert-Failure 'fake read in message literal' @('declared-not-read|key', 'no-reads-seen|*')
        Set-Fixture $declareKey "if Argument.GetRequestJson().Contains('key') then;"
        Assert-Clean 'typed inline request read'
        Set-Fixture $declareKey "if Unknown.GetRequestJson().Contains('key') then;"
        Assert-Failure 'unknown inline request source' @('declared-not-read|key', 'no-reads-seen|*')
        Set-Fixture $declareKey "Reader.ReadText(Argument, RequestJson, Name); Name := 'key';" $reader
        Assert-Failure 'key used before assignment' @('declared-not-read|key', 'no-reads-seen|*')
        Set-Fixture $declareKey "Reader.ReadText(Argument, AliasJson, 'key'); AliasJson := RequestJson;" $reader
        Assert-Failure 'request alias used before assignment' @('declared-not-read|key', 'no-reads-seen|*')
        Set-Fixture $declareKey "Clear(RequestJson); Reader.ReadText(Argument, RequestJson, 'key');" $reader
        Assert-Failure 'request cleared before reader' @('no-reads-seen|*')
        $keyWrite = $reader.Replace('        if Payload.Get(KeyName, Token) then;', "        KeyName := Pick();`n        if Payload.Get(KeyName, Token) then;")
        Set-Fixture $declareKey "Reader.ReadText(Argument, RequestJson, 'key');" $keyWrite
        Assert-Failure 'formal key overwritten' @('declared-not-read|key', 'no-reads-seen|*')
        $byRef = $reader.Replace('    procedure NeverCalled', @'
    procedure Mutate(var Name: Text)
    begin
        Name := Pick();
    end;
    procedure NeverCalled
'@)
        Set-Fixture $declareKey "Name := 'key'; Reader.Mutate(Name); Reader.ReadText(Argument, RequestJson, Name);" $byRef
        Assert-Failure 'known by-ref key mutation' @('declared-not-read|key', 'no-reads-seen|*')
        $cycle = $reader.Replace('        if Payload.Get(KeyName, Token) then;', '        Recurse(Payload, KeyName);')
        $cycle = $cycle.Replace('    procedure NeverCalled', @'
    local procedure Recurse(Payload: JsonObject; Name: Text)
    begin
        Recurse(Payload, Name);
    end;
    procedure NeverCalled
'@)
        Set-Fixture $declareKey "Reader.ReadText(Argument, RequestJson, 'key');" $cycle
        Assert-Failure 'cycle cannot fabricate a read' @('declared-not-read|key', 'no-reads-seen|*')
        $forwardParts = $parts.Replace('    procedure GetParameters', @'
    procedure Forward(Name: Text) Result: JsonArray
    var
        AliasName: Text;
    begin
        AliasName := Name;
        exit(GetParameters(AliasName));
    end;
    procedure GetParameters
'@)
        Set-Fixture "exit(Parts.Forward('A'));" "if RequestJson.Get('a', Token) then;" $forwardParts
        Assert-Clean 'selector alias forwarded through real formal'
        $unknownMutation = $parts.Replace('        if Selector in', "        UnknownChange(Selector);`n        if Selector in")
        Set-Fixture "exit(Parts.GetParameters('Empty'));" '' $unknownMutation
        Assert-Failure 'unknown call cannot preserve selector' @('unsupported-analysis|Parts ori::getparameters: unresolved Text selector selector', 'declared-not-read|a')
        Set-Fixture "Message('ContractMgt.Parameter(''key'', ''string'', false, ''Fake'')');" $readKey
        Assert-Failure 'builder syntax in string cannot declare key' @('read-not-declared|key')
        Set-Fixture $declareKey "// RequestJson.Get('key', Token)`n        Message('key');"
        Assert-Failure 'comment cannot prove a read' @('declared-not-read|key', 'no-reads-seen|*')
        $unsupported = New-Object 'System.Collections.Generic.List[string]'
        $unsupported.Add('Fixture.Get|unsupported-analysis|unavailable source')
        Assert-Context ((Compare-WithAllowList $unsupported $unsupported).Count -gt 0) 'unsupported analysis cannot be allow-listed'
        Write-Host "SelfTest (call contexts) passed: $script:ContextScenarios scenarios, $script:ContextChecks assertions."
    } finally { Remove-Item $root -Recurse -Force }
}
