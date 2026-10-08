<#
.SYNOPSIS
Protects the scoped #76 tag fixture and retry ordering. This is source evidence only.
#>
param(
    [string]$ProjectRoot = (Join-Path $PSScriptRoot '..'),
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'

function Remove-Comments([string]$Source) {
    $Source = [regex]::Replace($Source, '(?s)/\*.*?\*/', '')
    return [regex]::Replace($Source, '(?m)^\s*//.*$', '')
}

function Find-Problems([string]$Probe, [string]$Upgrade) {
    $Probe = Remove-Comments $Probe
    $Upgrade = Remove-Comments $Upgrade
    $problems = [System.Collections.Generic.List[string]]::new()
    if ($Probe -notmatch '(?m)^\s*RequiredTestIsolation\s*=\s*Function\s*;') {
        $problems.Add('96210 requires Function isolation for tag and role fixtures.')
    }
    if ($Probe -match '(?i)\bCommit\s*\(') {
        $problems.Add('96210 must not commit fixture changes.')
    }
    $fixture = [regex]::Match($Probe, '(?s)local procedure RemoveCompanyOrphanPurgeTag\(\).*?(?=\s+local procedure|\z)').Value
    $scopedDelete = 'UpgradeTags.Field(1).SetRange(OrphanPurgeTag());',
        'UpgradeTags.Field(3).SetRange(CompanyName());',
        'UpgradeTags.DeleteAll(false);'
    $last = -1
    foreach ($statement in $scopedDelete) {
        $index = $fixture.IndexOf($statement, [System.StringComparison]::Ordinal)
        if ($index -le $last) { $problems.Add('Tag deletion must filter both tag and company before DeleteAll.'); break }
        $last = $index
    }
    if ($fixture -match '(?i)\b(?:Reset|SetView|ChangeCompany)\s*\(') {
        $problems.Add('Tag fixture must not reset or redirect its scoped view.')
    }
    $retry = $Upgrade.IndexOf('Takeover.TryRunTakeOverAtInstall();', [System.StringComparison]::Ordinal)
    $tagCheck = $Upgrade.IndexOf('if UpgradeTag.HasUpgradeTag(', [System.StringComparison]::Ordinal)
    if ($retry -lt 0 -or $tagCheck -lt 0 -or $retry -ge $tagCheck) {
        $problems.Add('Company upgrade must retry takeover before the purge-tag check.')
    }
    return $problems.ToArray()
}

$probe = Get-Content (Join-Path $ProjectRoot 'test/test/StorageTakeoverProbeTests.Codeunit.al') -Raw
$upgrade = Get-Content (Join-Path $ProjectRoot 'app/src/Lifecycle/StorageLinkUpgrade.Codeunit.al') -Raw
$problems = @(Find-Problems $probe $upgrade)
if ($problems.Count) { throw ($problems -join "`n") }

if ($SelfTest) {
    $mutations = @(
        @{ Name = 'disabled isolation'; Probe = $probe.Replace('RequiredTestIsolation = Function;', 'RequiredTestIsolation = Disabled;'); Upgrade = $upgrade },
        @{ Name = 'commented isolation'; Probe = $probe.Replace('RequiredTestIsolation = Function;', '// RequiredTestIsolation = Function;'); Upgrade = $upgrade },
        @{ Name = 'missing company filter'; Probe = $probe.Replace('UpgradeTags.Field(3).SetRange(CompanyName());', ''); Upgrade = $upgrade },
        @{ Name = 'missing tag filter'; Probe = $probe.Replace('UpgradeTags.Field(1).SetRange(OrphanPurgeTag());', ''); Upgrade = $upgrade },
        @{ Name = 'fixture commit'; Probe = $probe.Replace('UpgradeTags.DeleteAll(false);', 'Commit(); UpgradeTags.DeleteAll(false);'); Upgrade = $upgrade },
        @{ Name = 'reset scoped view'; Probe = $probe.Replace('UpgradeTags.DeleteAll(false);', 'UpgradeTags.Reset(); UpgradeTags.DeleteAll(false);'); Upgrade = $upgrade },
        @{ Name = 'missing retry'; Probe = $probe; Upgrade = $upgrade.Replace('Takeover.TryRunTakeOverAtInstall();', '') },
        @{ Name = 'retry after tag'; Probe = $probe; Upgrade = $upgrade.Replace('Takeover.TryRunTakeOverAtInstall();', '') + "`nTakeover.TryRunTakeOverAtInstall();" }
    )
    foreach ($mutation in $mutations) {
        if (@(Find-Problems $mutation.Probe $mutation.Upgrade).Count -eq 0) {
            throw "Mutation escaped guard: $($mutation.Name)"
        }
    }
    Write-Host "Takeover source guard: baseline and $($mutations.Count) negative mutations passed. Runtime rollback not tested."
} else {
    Write-Host 'Takeover source guard passed. Runtime rollback and permission acceptance remain separate.'
}
