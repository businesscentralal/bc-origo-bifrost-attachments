<#
.SYNOPSIS
    Keeps Attachments behind the platform external-file-storage connector interfaces.
.DESCRIPTION
    Rejects provider-specific connector dispatch, provider account-table/schema access, and
    concrete connector app dependencies in production sources. Connector enum values may
    still be enumerated and serialized as opaque identifiers. Comments, text labels and
    unrelated object IDs are not evidence of connector dispatch. There is no allow-list.
.PARAMETER AppFolder
    Production AL app folder, including app.json (default: ../app).
.PARAMETER SelfTest
    Runs mutation fixtures for dispatch, metadata access and dependencies, plus clean controls.
#>
param(
    [string]$AppFolder = (Join-Path $PSScriptRoot '../app'),
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$ProviderIds = '4560|4570|4580|4621'
$AccountName = 'Ext\. (?:Blob Storage|File Share|SharePoint|SFTP) Account'
$MetadataName = 'Storage Account Name|Container Name|File Share Name|SharePoint Url|Base Relative Folder Path'
$ConnectorAppIds = @(
    'c9ce86fe-cb70-4b79-be03-d21856b1a4ca',
    '79447b11-8301-4d02-a546-2261eb811296',
    '34bfcef7-f8ed-449f-94be-74024cadba3b',
    'e0df20ef-75a2-4fae-8e3a-88140ab29507'
)

function Remove-AlComments([string]$Text) {
    # Match strings before comments: a URL or // inside an AL literal is not a comment.
    $parts = [regex]::new('''(?:[^'']|'''')*''|"(?:[^"]|"")*"|//[^\r\n]*|/\*[\s\S]*?\*/')
    return $parts.Replace($Text, {
        param($match)
        if ($match.Value.StartsWith('//') -or $match.Value.StartsWith('/*')) {
            return [regex]::Replace($match.Value, '[^\r\n]', ' ')
        }
        return $match.Value
    })
}

function Find-ConnectorViolations([string]$Folder) {
    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($file in Get-ChildItem -LiteralPath $Folder -Recurse -File -Filter '*.al') {
        $relative = [IO.Path]::GetRelativePath($Folder, $file.FullName).Replace('\', '/')
        $source = Remove-AlComments ([IO.File]::ReadAllText($file.FullName))
        $code = [regex]::Replace($source, "'(?:[^']|'')*'", { param($m) [regex]::Replace($m.Value, '[^\r\n]', ' ') })
        $findings = [System.Collections.Generic.List[object]]::new()
        foreach ($match in [regex]::Matches($source, ('(?i)(?:"{0}"|''{0}'')' -f $AccountName))) {
            if ($source.Substring(0, $match.Index) -match '(?i)(?:\bLabel|\b(?:Caption|ToolTip|InstructionalText|Comment)\s*=)\s*$') { continue }
            $findings.Add(@{ Index = $match.Index; Rule = 'provider-account-table' })
        }
        foreach ($match in [regex]::Matches($source, "(?i)'(?:$MetadataName)'")) {
            if ($source.Substring(0, $match.Index) -match '(?i)(?:\bLabel|\b(?:Caption|ToolTip|InstructionalText|Comment)\s*=)\s*$') { continue }
            # Literal account field names are schema knowledge, even when a helper opens by variable ID.
            $findings.Add(@{ Index = $match.Index; Rule = 'provider-account-schema' })
        }
        foreach ($match in [regex]::Matches($code, "(?i)\btabledata\s+(?:$ProviderIds)\s*=|\.\s*Open\s*\(\s*(?:$ProviderIds)\b")) {
            $findings.Add(@{ Index = $match.Index; Rule = 'provider-account-access' })
        }

        $selectors = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($name in @('Connector', 'ConnectorId', 'Provider', 'ProviderId', 'Backend', 'BackendId')) { [void]$selectors.Add($name) }
        foreach ($match in [regex]::Matches($code, '(?i)\b(\w+)\s*:\s*Enum\s+"Ext\. File Storage Connector"')) { [void]$selectors.Add($match.Groups[1].Value) }
        # Follow aliases in source order. This recognizes local names without treating arbitrary numeric IDs as providers.
        foreach ($match in [regex]::Matches($code, '(?i)\b(\w+)\s*:=\s*([^;]+);')) {
            $selectorPattern = '\b(?:' + (($selectors | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b'
            $selectorExpression = '(?:\b\w+\s*\.\s*)?' + $selectorPattern + '(?:\s*\.\s*AsInteger\s*\(\s*\))?'
            if ($match.Groups[2].Value -match ('(?i)^\s*' + $selectorExpression + '\s*$')) { [void]$selectors.Add($match.Groups[1].Value) }
        }
        $selectorPattern = '\b(?:' + (($selectors | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b'
        $selectorExpression = '(?:\b\w+\s*\.\s*)?' + $selectorPattern + '(?:\s*\.\s*AsInteger\s*\(\s*\))?'
        $comparison = '\s*(?:=|<>|<=|>=|<|>)\s*'
        $enumLiteral = '(?:\bEnum\s*::\s*"[^"]+"|\b\w+)\s*::\s*(?:"[^"]+"|\w+)'
        # Match literals attached to the connector expression itself. An opaque connector equality
        # beside an unrelated numeric comparison is valid and must not be mistaken for dispatch.
        $literalDispatch = '(?i)(?:' + $selectorExpression + $comparison + '(?:-?\d+\b|' + $enumLiteral + ')|' +
            '(?:\b\d+|' + $enumLiteral + ')' + $comparison + $selectorExpression + '|' +
            $selectorExpression + '\s+(?:not\s+)?in\s*\[[^\]]*(?:\d+|' + $enumLiteral + ')[^\]]*\])'
        foreach ($match in [regex]::Matches($code, $literalDispatch)) {
            $findings.Add(@{ Index = $match.Index; Rule = 'provider-dispatch' })
        }

        $tokens = @([regex]::Matches($code, '"(?:[^"]|"")*"|\b\w+\b|::|[^\s]'))
        for ($i = 0; $i -lt $tokens.Count; $i++) {
            if ($tokens[$i].Value -ine 'case') { continue }
            $of = $i + 1
            while ($of -lt $tokens.Count -and $tokens[$of].Value -ine 'of') { $of++ }
            if ($of -ge $tokens.Count) { continue }
            $selector = $code.Substring($tokens[$i].Index, $tokens[$of].Index - $tokens[$i].Index)
            $depth = 1
            for ($j = $of + 1; $j -lt $tokens.Count; $j++) {
                $value = $tokens[$j].Value
                if ($value -ieq 'case' -or $value -ieq 'begin') { $depth++ }
                if ($value -ieq 'end') { $depth--; if ($depth -eq 0) { break } }
                $literalArm = ($depth -eq 1) -and ($selector -match $selectorPattern) -and
                    ($value -match '^(?:\d+|"[^"]+"|\w+)$') -and ($j + 1 -lt $tokens.Count) -and
                    ($tokens[$j + 1].Value -in @(':', ','))
                if ($literalArm) { $findings.Add(@{ Index = $tokens[$j].Index; Rule = 'provider-dispatch' }) }
            }
        }
        foreach ($finding in $findings | Sort-Object Index, Rule -Unique) {
            $line = 1 + [regex]::Matches($source.Substring(0, $finding.Index), '\n').Count
            $problems.Add("${relative}:${line}: [$($finding.Rule)] use the platform connector interface, without provider-specific knowledge")
        }
    }
    $manifestPath = Join-Path $Folder 'app.json'
    if (Test-Path -LiteralPath $manifestPath) {
        $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
        foreach ($dependency in $manifest.dependencies) {
            if ($dependency.id -in $ConnectorAppIds -or $dependency.name -match '(?i)^External File Storage\s*-\s*.+Connector$') {
                $problems.Add("app.json: [concrete-connector-dependency] $($dependency.name) ($($dependency.id))")
            }
        }
    }
    return $problems.ToArray()
}

if ($SelfTest) {
    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('connector-guard-' + [guid]::NewGuid().ToString('N'))
    $fixtures = @(
        @{ Name = 'numeric case'; Rule = 'provider-dispatch'; Code = 'case ConnectorId of 4560: HandleBlob(); end;' },
        @{ Name = 'numeric if'; Rule = 'provider-dispatch'; Code = 'if (ConnectorId = 4570) then Refuse();' },
        @{ Name = 'custom numeric case'; Rule = 'provider-dispatch'; Code = 'case ConnectorId of 123456: CustomBehavior(); end;' },
        @{ Name = 'custom numeric if'; Rule = 'provider-dispatch'; Code = 'if Setup.Connector.AsInteger() = 123456 then CustomBehavior();' },
        @{ Name = 'custom Boolean policy'; Rule = 'provider-dispatch'; Code = 'CaseSensitive := ConnectorId <> 123456;' },
        @{ Name = 'custom membership'; Rule = 'provider-dispatch'; Code = 'if ConnectorId in [123456, 987654] then Refuse();' },
        @{ Name = 'custom named enum case'; Rule = 'provider-dispatch'; Code = 'Kind: Enum "Ext. File Storage Connector"; case Kind of Kind::"Custom Provider": Refuse(); end;' },
        @{ Name = 'custom named enum if'; Rule = 'provider-dispatch'; Code = 'Kind: Enum "Ext. File Storage Connector"; if Kind = Kind::"Custom Provider" then Refuse();' },
        @{ Name = 'custom named enum reverse'; Rule = 'provider-dispatch'; Code = 'if Enum::"Ext. File Storage Connector"::"Custom Provider" = Setup.Connector then Refuse();' },
        @{ Name = 'Boolean policy assignment'; Rule = 'provider-dispatch'; Code = 'CaseSensitive := not (Setup.Connector.AsInteger() = 4570);' },
        @{ Name = 'policy return'; Rule = 'provider-dispatch'; Code = 'exit(ConnectorId <> 4580);' },
        @{ Name = 'reverse comparison'; Rule = 'provider-dispatch'; Code = 'if 4580 = Setup.Connector.AsInteger() then HandleSharePoint();' },
        @{ Name = 'connector alias'; Rule = 'provider-dispatch'; Code = 'Kind := Setup.Connector.AsInteger(); case Kind of 4621: Refuse(); end;' },
        @{ Name = 'typed selector'; Rule = 'provider-dispatch'; Code = 'Kind: Enum "Ext. File Storage Connector"; case Kind.AsInteger() of 4560: Refuse(); end;' },
        @{ Name = 'named enum case'; Rule = 'provider-dispatch'; Code = 'case Connector of Connector::SharePoint: Refuse(); end;' },
        @{ Name = 'named enum if'; Rule = 'provider-dispatch'; Code = 'Kind: Enum "Ext. File Storage Connector"; if Kind = Kind::"Azure Blob Storage" then Refuse();' },
        @{ Name = 'later case arm'; Rule = 'provider-dispatch'; Code = 'case ConnectorId of 0: begin Generic(); end; 4580: Refuse(); end;' },
        @{ Name = 'RecordRef Open'; Rule = 'provider-account-access'; Code = 'Account: RecordRef; Account.Open(4580);' },
        @{ Name = 'provider table grant'; Rule = 'provider-account-access'; Code = 'Permissions = tabledata 4560 = R;' },
        @{ Name = 'named provider record'; Rule = 'provider-account-table'; Code = 'Account: Record "Ext. Blob Storage Account";' },
        @{ Name = 'metadata table name'; Rule = 'provider-account-table'; Code = "if Account.Name <> 'Ext. SharePoint Account' then Error('schema');" },
        @{ Name = 'metadata field'; Rule = 'provider-account-schema'; Code = "RootField := 'Container Name'; Account.Field(4).Value := RootField;" },
        @{ Name = 'concrete dependency ID'; Rule = 'concrete-connector-dependency'; Code = ''; Dependencies = @(@{ id = $ConnectorAppIds[0]; name = 'Renamed package' }) },
        @{ Name = 'concrete dependency name'; Rule = 'concrete-connector-dependency'; Code = ''; Dependencies = @(@{ id = [guid]::NewGuid().ToString(); name = 'External File Storage - Future Service Connector' }) },
        @{ Name = 'opaque roster'; Rule = ''; Code = 'foreach ConnectorId in Connector.Ordinals() do begin Connector := Enum::"Ext. File Storage Connector".FromInteger(ConnectorId); Json.Add(Format(Connector.AsInteger(), 0, 9)); end;' },
        @{ Name = 'platform enum'; Rule = ''; Code = 'if Entry.Type = Entry.Type::Directory then exit(true);' },
        @{ Name = 'opaque connector equality'; Rule = ''; Code = 'if (Setup.Connector = OtherSetup.Connector) and (Count > 0) then exit(true);' },
        @{ Name = 'opaque serialized scope'; Rule = ''; Code = 'Scope := Format(Setup.Connector.AsInteger(), 0, 9);' },
        @{ Name = 'unrelated object and value'; Rule = ''; Code = 'codeunit 4560 "Example ori" { if Count = 4570 then exit(); case Count of 4580: exit(); end; }' },
        @{ Name = 'comments and label'; Rule = ''; Code = "// if ConnectorId = 4560 then Refuse();`n/* Account.Open(4580); */`nInfoLbl: Label 'if ConnectorId = 4560 then Refuse(); SharePoint supports folders.';" }
        @{ Name = 'display field name'; Rule = ''; Code = "InfoLbl: Label 'Container Name'; Caption = 'Ext. Blob Storage Account';" }
    )
    try {
        New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
        foreach ($fixture in $fixtures) {
            [IO.File]::WriteAllText((Join-Path $fixtureRoot 'Fixture.al'), $fixture.Code)
            $dependencies = if ($fixture.ContainsKey('Dependencies')) { @($fixture.Dependencies) } else { @() }
            [IO.File]::WriteAllText((Join-Path $fixtureRoot 'app.json'), (@{ dependencies = $dependencies } | ConvertTo-Json -Depth 5))
            $actual = @(Find-ConnectorViolations $fixtureRoot)
            if ($fixture.Rule) {
                if (-not ($actual | Where-Object { $_.Contains('[' + $fixture.Rule + ']') })) {
                    throw "SelfTest failed: $($fixture.Name) did not detect $($fixture.Rule). Findings: $actual"
                }
            }
            elseif ($actual.Count -ne 0) { throw "SelfTest failed: clean control $($fixture.Name): $actual" }
        }
    }
    finally {
        # Only delete the newly-created guard fixture root, after verifying its resolved parent and prefix.
        $resolved = [IO.Path]::GetFullPath($fixtureRoot)
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
        if ([IO.Path]::GetDirectoryName($resolved) -ne $tempRoot -or [IO.Path]::GetFileName($resolved) -notlike 'connector-guard-*') { throw 'Unsafe fixture cleanup path.' }
        if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    }
    Write-Host "Connector abstraction SelfTest passed: $($fixtures.Count) mutation/control fixtures."
    exit 0
}

$problems = @(Find-ConnectorViolations ([IO.Path]::GetFullPath($AppFolder)))
if ($problems.Count) {
    Write-Host '::error::Attachments contains concrete provider knowledge; use the platform connector abstraction.'
    $problems | ForEach-Object { Write-Host $_ }
    exit 1
}
Write-Host 'Attachments uses the connector abstraction without concrete provider dispatch, metadata access or dependencies.'
