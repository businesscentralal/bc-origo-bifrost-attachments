---
title: Prepare the Attachments submission package
audience: release-owner
keywords: AppSource, Attachments, release, validation
locale: en-US
---

# Prepare the Attachments submission package

**Status: pre-QA planning material for a new Attachments offer. No Partner Center offer currently exists.** Issue [#81](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/81) owns these artifacts; [#83](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/83) coordinates release gates. This package does not certify a candidate.

Gunnar confirmed on 2026-10-06 that Attachments has no Partner Center offer and no existing offer product ID. A future operator-owned release step must create the genuine Attachments offer under separate authorization and supply its ID for internal review. Keep `deliverToAppSource` unconfigured until then. Do not reuse Foundation's ID or invent a placeholder. Offer creation, submission and publication are outside this assignment. This decision does not establish whether a historical app validation baseline exists; verify that independently.

| Artifact | Purpose |
|---|---|
| [release-checklist.md](release-checklist.md) | Evidence and named blockers for the offer owner |
| [scenario-plan.md](scenario-plan.md) | Coverage, independent fixtures and evidence needed before formal scenarios |
| [validator-smoke-script.md](validator-smoke-script.md) | Gated manual smoke script for a validator-owned sandbox |
| [partner-center-markets.csv](partner-center-markets.csv) | Fourteen source-declared country codes, without a validation claim |
| [source-inventory.json](source-inventory.json) | Audited manifest, source hashes and all 34 currently declared wire types |

After issue #80 proves internal QA on an immutable candidate and the existing explicit QA hold is released, worker-6 must regenerate the inventory from that source, reconcile every plan row with tested UI and message contracts, and produce `AppSource-UserScenarios.md` using the standards `origo-bc-appsource-validation` format. Every formal scenario needs Setup, Steps, Expected Results and Cleanup, and an evidence reference. Include publisher, actual packaged version, submission date and validator environment instructions. Record the full source SHA, signed-package SHA256, Foundation package version/hash, BC release/country, compiler/analyzers and actual test counts. Repeat the validator dry-run before handing off. An unrun row stays blocked and cannot be represented as certified.

These files are submission working material, not published product help. Established documentation owners retain the external documentation site. Coordinate corrections, asset publication and help/legal/support acceptance through internal-review. Do not copy Foundation's offer identity or credentials.

## Record the approved working-material location

| Decision | Current disposition |
|---|---|
| Internal request `attachments81-worker6-submission-location-20261006` | Resolved 2026-10-06: approved with conditions. `app/docs/appsource` is the bounded #81 submission workspace; draft PR88 is permitted while incomplete. |
| Scope | Maintain these working inventories, plan, checklist and assets now. Published help stays with its existing owners. Before final delivery, confirm documentation tooling does not publish/convert this submission directory. |
| Gates | No gateway pass or QA/publication release was granted. Formal `AppSource-UserScenarios.md` and the smoke dry-run require immutable #80 passing QA and the existing explicit QA hold release. |

## Use the current approved dependency input

| Field | Independently checked 2026-10-07 |
|---|---|
| Foundation | `28.0.2.523`, source `336b91d9fff11b71ae5cd75dee08186d4218bf07`, run `37544940349`, attempt `2`, artifact `11459147009` |
| Package SHA256 | `5901bebe66b44e91ed6110620e62ee45d122ba9e0378dcfda4aeef4d00d3ae0f` |
| Evidence limits | Exact archive digest, package bytes, manifest/build/source and zero friend grants checked. Windows NAVX signature trust is not verified by this materials run. This input has not been deployed/tested on PR88. |
| Unchanged floor | Foundation minimum `28.0.1.0`. Historical 517/518 inputs are not current acceptance evidence. |

The inventory remains tied to unchanged Attachments product source `b42ad90eaee2803205408a1cac8b0d9752b91c0e`. PR84 / worker-3 is the sole canonical compile/product/test repair. Its merge gates assembled-candidate/runtime evidence, while this documentation preparation is permitted now. PR87 / worker-8 remains donor-only on explicit hold; PR91 has a separate pipeline owner. No third repair is authorized.
