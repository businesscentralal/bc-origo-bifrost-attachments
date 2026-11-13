---
title: Reconcile Attachments release evidence on 11 November 2026
audience: release-owner
keywords: Attachments, submission, release, candidate, validation
locale: en-US
---

# Use the evidence for its recorded candidate

| Evidence | Recorded identity | Boundary |
|---|---|---|
| [Released 28.3.2](https://github.com/businesscentralal/bc-origo-bifrost-attachments/releases/tag/28.3.2) | Source `c9395bbbc2c208f9c425a92457876234d54c1a3b`; release Apps asset `732456689` | The release identifies source and assets. Do not infer a package hash, signer or installed Foundation hash from the tag. |
| [Architect's #80 closure](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/80#issuecomment-6805877107) | Microsoft validation and go-live of Attachments 28.3.2 on 10 November; submission `1152921505800014035` | Architect accepted the signed package, Foundation dependency and offer markets for #80 AC01–AC03. This supersedes the old statement that #80 QA is still open. It supplies no new per-scenario execution counts here. |
| [Merged preparation PR220](https://github.com/businesscentralal/bc-origo-bifrost-attachments/pull/220) | Main `dc81655b6ce9368635e8d899348ca2247e94c54d`; source manifest `28.3.3.0`; 41 declared message types, including disabled `DataExchange.Definition.Delete` | Later preparation source, not the released 28.3.2 artifact. The version increment in PR221 preceded this merge. |
| [Tester UAT for PR220](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/81#issuecomment-6806369735) | Installed Attachments `28.3.3.151`, Foundation `28.0.12.680`; CI43091721486 | Catalogue and Create/Get/Delete smoke, with cleanup reported by Tester. It does not prove every formal validator scenario or a different artifact. |
| [Architect's #81 reopening](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/81#issuecomment-6806380993) | #81 AC01–AC04 remain open; submission stays on hold | Neither #80 closure nor the preparation merge closes this issue or grants another publication approval. |

The [8 November reconciliation](preparation-2026-11-08.md) and [build113 receipt](candidate-2026-10-20.json) remain dated records. Current source manifests require Foundation `28.0.11.669` (product) and `28.0.11.0` (tests); those floors are distinct from the installed version above. The configured offer ID remains `ae26bc25-7547-42ec-a1b7-c55e3b830569`, with `continuousDelivery: false`. No offer, workflow, market, manifest or AL object is changed by this reconciliation.

## Finish #81 without reopening completed QA

| Acceptance | Already present | Remaining action / owner |
|---|---|---|
| AC01 | P01–P13 plan and coverage of all 41 declared types | The #81 developer needs the proven payloads, visible UI expectations and cleanup receipts for the selected scenario candidate before producing independent Setup / Steps / Expected Results / Cleanup documents. Architect/Tester supply the applicable evidence; do not require #80 to reopen. |
| AC02 | Released source/asset identity and later preparation source are distinguished above | Architect identifies which exact signed artifact the formal document targets and provides its package/dependency provenance. Freeze only results proved for that candidate. A release-wide validation verdict does not supply missing step-level observations. |
| AC03 | Fourteen-country source list, configured offer ID and draft assets | Gunnar/designated offer, legal, support and documentation owners supply the accepted material revisions, mapping and secure validator access. Preserve Architect's accepted #80 market verdict; do not request another generic 14-country run as a #81 prerequisite. |
| AC04 | Owned-sandbox manual script and local receipt checker | The #81 developer executes the script after exact-candidate scenario inputs and authorized validator access are available; record actual counts and absence of owned fixtures. No dry-run pass is claimed here. |
| Signed package | [8 November Windows receipt](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/81#issuecomment-6727107458): Valid/HashMismatch, Origo hf thumbprint `2AD5FF188D0B22858A2813817A929BCC1EC03E4A`, artifact `13458705165`, package `28.3.2.143`, SHA256 `ad32e013bfef68ac30f746c32daefdf52601591760d25fecda682ba08a62af4f` | Attach the matching receipt to the selected artifact; the build143 result does not verify release149 or build151 bytes. #81 retains the per-artifact check. |

Architect moved live Azure File Share and SharePoint smoke to a **parked Gunnar follow-up** in the #80 closure. Preserve that no-action hold. This preparation neither executes those probes nor reclassifies them as passes; it does not duplicate the follow-up under #81. Any formal scenario requiring those providers remains visibly unverified until authorized evidence is supplied.

The validator script requires a validator-owned sandbox, self-created data and secure external access references. Keep credentials out of repository documents. A local receipt checker validates consistency only; a green checker cannot replace the missing dry run, operator approvals or genuine provider receipts. Gunnar must approve every new AppSource publication; this reconciliation authorizes none.
