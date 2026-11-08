<#
.SYNOPSIS
    Verifies the #192 Foundation staging boundary: Attachments has no Orchestrator dependency or AL reference.
#>
param([string]$AppFolder = (Join-Path $PSScriptRoot '../app'))
$ErrorActionPreference = 'Stop'
$manifest = Get-Content -LiteralPath (Join-Path $AppFolder 'app.json') -Raw | ConvertFrom-Json
$dependencies = @($manifest.dependencies | Where-Object { $_.name -match '(?i)orchestrator' })
if ($dependencies.Count -gt 0) { throw 'Attachments must not depend on Orchestrator.' }
$references = @(Get-ChildItem -LiteralPath $AppFolder -Recurse -Filter '*.al' | Select-String -Pattern '(?i)\busing\s+Origo\.Bifrost\.Orchestrator\b|\bOrigo\.Bifrost\.Orchestrator\.')
if ($references.Count -gt 0) { throw "Attachments must not reference Orchestrator AL objects: $($references.Path -join ', ')" }
Write-Output 'Attachments has no Orchestrator dependency or AL namespace reference.'
