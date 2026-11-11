---
title: Prepare the Attachments submission package
audience: release-owner
keywords: AppSource, Attachments, release, validation
locale: en-US
---

# Prepare the Attachments submission package

## Current source preparation — 8 November 2026

Inspected source: [`b7310c3308e5cb216b6aa5ff0db2ca5645607d6b`](https://github.com/businesscentralal/bc-origo-bifrost-attachments/commit/b7310c3308e5cb216b6aa5ff0db2ca5645607d6b). See the [8 November preparation reconciliation](preparation-2026-11-08.md) for current manifest, offer configuration and acceptance gaps. No final QA candidate is certified. [Build113](candidate-2026-10-20.json) remains historical evidence for its own bytes only.

## Historical technical receipt — 20 October 2026

The historical inspected build is main `c30c2254bf953ed2e6f90fdf080dfb216bea799f`, [CI39298155811](https://github.com/businesscentralal/bc-origo-bifrost-attachments/actions/runs/39298155811), signed Default **28.0.0.113**, SHA256 `e68e79c6450d9c666b928b91022905cf78fccd35466a86db769c3e6476e950a6`, with no friend grants. Both product modes and the test app compiled with CodeCop/UICop/AppSourceCop and 0 errors/0 warnings. Existing CI native suite: **365 executed / 365 passed / 0 failed / 0 skipped**; this is audited CI evidence, not a new validator run. All eight artifact ZIP digests match GitHub. [The immutable preparation receipt](candidate-2026-10-20.json) records identities and evidence boundaries.

PR147 integrated the Pipeline gate, no-files-fail output upload and final receipt upload. PR149 intentionally deferred Signed enforcement after the hosted-runner SIP/trust failure; preserve that disposition. Root’s independent Windows receipt for this exact build113 artifact now reports **Valid**, signer **Origo hf**, DigiCert timestamp and **HashMismatch** for its tampered copy. The receipt below preserves both signed and pre-sign identities. Architect/Gunnar still owns the certificate/release disposition. PR152–155 are merged; references below to their moving candidate or build109 are historical context. No old build receipt verifies a new artifact.

[Executable preparation and smoke-receipt checks](validator-evidence-format.md) are available now. They make no network calls and never certify an app. Formal scenarios and an actual validator-owned sandbox dry-run remain dependent on passing exact-candidate #80 QA. Legal/support/registration/provider/identity/offer inputs retain their named owners; no offer creation, submission or publication.

**Pre-QA working material. No candidate is certified by this package.** Þráinn (worker-8) owns this #81 preparation under the 8 November authoritative handoff. Follow the current #80 assignment for QA; historical worker names are not custody instructions. Architect coordinates the final candidate and release gates.

The 6 October no-offer decision is historical. Merged [PR176](https://github.com/businesscentralal/bc-origo-bifrost-attachments/pull/176) configured the Attachments product ID `ae26bc25-7547-42ec-a1b7-c55e3b830569` with `continuousDelivery: false`. Repository configuration is not a fresh Partner Center mapping check or publication approval. The [5 November hold](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/81#issuecomment-6666652824) permits preparation only; Gunnar must approve every AppSource publish.

| Artifact | Purpose |
|---|---|
| [preparation-2026-11-08.md](preparation-2026-11-08.md) | Current source facts, historical receipt boundaries and named acceptance dependencies |
| [release-checklist.md](release-checklist.md) | Source evidence, release inputs and named owners |
| [scenario-plan.md](scenario-plan.md) | Coverage and independent fixtures; not formal validator scenarios |
| [validator-smoke-script.md](validator-smoke-script.md) | Manual script gated on candidate QA; not executed |
| [partner-center-markets.csv](partner-center-markets.csv) | Fourteen source-declared countries; no validation claim |
| [market-evidence-plan.md](market-evidence-plan.md) | Per-market acceptance fields and owner handoff |
| [validator-evidence-format.md](validator-evidence-format.md) | Executable local preparation/preflight and actual smoke receipt format |
| [candidate-2026-10-20.json](candidate-2026-10-20.json) | Immutable build113 technical evidence; external certification pending |
| [source-inventory.json](source-inventory.json) | Committed source/manifest hashes and 41 declared wire types (one disabled) |

## Prepare now; formalize after candidate QA

[Architect's 16 October candidate decision](https://bifrst-group.slack.com/archives/C0C0XM70YF8/p1792179827684749) explicitly authorizes checklist, scenario-plan and market preparation now. Formal `AppSource-UserScenarios.md` and the validator dry-run follow passing #80 QA on the integrated candidate. There is no additional internal-review gate.

The historical inspected main contains all inputs from Architect’s integrated-source decision and PR144–155. Its exact technical evidence is linked above. Build87 (`b66d1f2`) is excluded. A newer main or differently signed artifact needs its own evidence; do not transfer this receipt to it. #80 QA on the named candidate remains pending.

After passing QA, regenerate the inventory, bind the signed app and every installed dependency by full source SHA/version/hash, and reconcile all plan rows against proven UI and public message contracts. Generate the independent Microsoft-format document with Publisher, packaged Version, Submission Date, Test Environment and numbered Setup / Steps / Expected Results / Cleanup per scenario. Preserve unrun categories as blockers. Record compiler/analyzers, BC country/build, languages, actual test counts, provider fixtures and cleanup. Then perform the owned validator dry-run.

## Preserve custody and evidence boundaries

`app/docs/appsource` remains the approved submission-artifact location from the 6 October location decision. PR88 and PR105 are historical merged preparation; PR118 supplied updates but no formal scenario delivery. This folder is working submission material, not external product help. External documentation owners retain their site; coordinate published changes through Architect and those owners. Confirm the documentation tooling excludes this folder before final delivery.

Generate the source inventory with `python3 tools/generate_source_inventory.py --ref <full-source-sha>` and check it with `--check`. It inventories committed bytes and preserves curated fields, which must also be reconciled manually. The local standards snapshot metadata records `52ba4754cfd614e4a7c50af87b30149b18b313e3`, captured 2 November and synced 3 November. This preparation does not claim a fresh synchronization. Apply current operator rules over superseded snapshot instructions.

Foundation 523 and build113 are historical evidence only. The current product manifest requires Foundation 28.0.11.669; the test manifest declares 28.0.11.0. Record the actual compatible installed version and package hash separately. Installed-runtime Foundation hash reconciliation stays open under #78/#80. Build113 Default Windows signature trust and tamper evidence is recorded above; a differently signed artifact needs fresh evidence. Use the exact accepted candidate dependency and the connector apps actually installed in each market. No credentials belong in these files.

Clean developer-owned test data after each scenario and verify it. Record the development container name/id, restart that same container for amendments, and retain it until Bifröst Tester passes post-deployment UAT and the issue closes under rule1792155806. Then delete only the owned resource and retain deletion readback. UAT has no test-data cleanup requirement; Claude verifies only on its own assigned environment. Record actual environment IDs and execution status in the acceptance receipt; this working document supplies no runtime pass.
