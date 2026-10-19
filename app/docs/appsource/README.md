---
title: Prepare the Attachments submission package
audience: release-owner
keywords: AppSource, Attachments, release, validation
locale: en-US
---

# Prepare the Attachments submission package

**Pre-QA working material. No candidate is certified by this package.** [#81](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/81) belongs to Reginn (worker-6); [#80](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/80) QA belongs to Þráinn (worker-8). Architect coordinates integration and release gates through #83.

Gunnar's 2026-10-06 decision was that Attachments had no Partner Center offer. This is the dated decision, not a fresh Partner Center lookup. Prepare a new-offer package; do not request an existing ID. Keep `deliverToAppSource` unconfigured until separately authorized offer creation supplies a genuine Attachments ID and its app mapping is confirmed. Never reuse Foundation's ID. Offer creation, submission and publication need separate authority; Gunnar must approve every AppSource publish.

| Artifact | Purpose |
|---|---|
| [release-checklist.md](release-checklist.md) | Source evidence, release inputs and named owners |
| [scenario-plan.md](scenario-plan.md) | Coverage and independent fixtures; not formal validator scenarios |
| [validator-smoke-script.md](validator-smoke-script.md) | Manual script gated on candidate QA; not executed |
| [partner-center-markets.csv](partner-center-markets.csv) | Fourteen source-declared countries; no validation claim |
| [market-evidence-plan.md](market-evidence-plan.md) | Per-market acceptance fields and owner handoff |
| [source-inventory.json](source-inventory.json) | Committed source/manifest hashes and 39 declared wire types |

## Prepare now; formalize after candidate QA

[Architect's 16 October candidate decision](https://bifrst-group.slack.com/archives/C0C0XM70YF8/p1792179827684749) explicitly authorizes checklist, scenario-plan and market preparation now. Formal `AppSource-UserScenarios.md` and the validator dry-run follow passing #80 QA on the integrated candidate. There is no additional internal-review gate.

The candidate is the main head with every input of that decision integrated (#72, worker-3's #122 repair, PR127, PR128 and PR129, all merged), meaningful green Default + Test and a Default Apps artifact. Today that is main `304a1c24985a00fb86b5caef10ca46ffe04096b6`: [CI/CD run 39276099802](https://github.com/businesscentralal/bc-origo-bifrost-attachments/actions/runs/39276099802) passed Default, Test (354 executed, 0 failed, 0 skipped) and Deploy to Bifrost, and the Default package is 28.0.0.109 with empty `InternalsVisibleTo` and Bifrost Foundation 28.0.3.530 as its only dependency. Storage connectors are interface-only (PR118, PR144), so no connector app is a package dependency. The signed NAVX gate is deferred (PR149, #78). PR152 (#120) merged after this receipt as `1f9d72a`, so the candidate moves to the main head that contains it, which needs its own receipts. Build 87 (`b66d1f2`) is explicitly excluded; #80 QA on the candidate SHA is still pending, and document only what actually ships.

After passing QA, regenerate the inventory, bind the signed app and every installed dependency by full source SHA/version/hash, and reconcile all plan rows against proven UI and public message contracts. Generate the independent Microsoft-format document with Publisher, packaged Version, Submission Date, Test Environment and numbered Setup / Steps / Expected Results / Cleanup per scenario. Preserve unrun categories as blockers. Record compiler/analyzers, BC country/build, languages, actual test counts, provider fixtures and cleanup. Then perform the owned validator dry-run.

## Preserve custody and evidence boundaries

`app/docs/appsource` remains the approved submission-artifact location from the 6 October location decision. PR88 and PR105 are historical merged preparation; PR118 supplied updates but no formal scenario delivery. This folder is working submission material, not external product help. External documentation owners retain their site; coordinate published changes through Architect and those owners. Confirm the documentation tooling excludes this folder before final delivery.

Generate the source inventory with `python3 tools/generate_source_inventory.py --ref <full-source-sha>` and check it with `--check`. It inventories committed bytes and preserves curated fields, which must also be reconciled manually. The standards snapshot is `ac05e88ab51ed4c9bbfb843508fc2484afe5ec8f`, synchronized 2026-10-03; it is not freshly synchronized. Apply current operator rules over superseded snapshot instructions.

Foundation 523 is historical evidence only. Source and the candidate package now require Foundation 28.0.3.530, which AL-Go takes from the core 28.0.3 GitHub release (PR151). Installed-runtime hash reconciliation and Windows signature trust stay open under #78. Use the exact accepted candidate dependency and the connector apps actually installed in each market. No credentials belong in these files.

Clean developer-owned test data after each scenario and verify it. Record the development container name/id, restart that same container for amendments, and retain it until Bifröst Tester passes post-deployment UAT and the issue closes under rule1792155806. Then delete only the owned resource and retain deletion readback. UAT has no test-data cleanup requirement; Claude verifies only on its own assigned environment. Record actual environment IDs and execution status in the acceptance receipt; this working document supplies no runtime pass.
