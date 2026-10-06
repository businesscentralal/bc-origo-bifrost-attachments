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

After issue #80 proves internal QA on an immutable candidate, worker-6 must regenerate the inventory from that source, reconcile every plan row with tested UI and message contracts, and produce `AppSource-UserScenarios.md` using the standards `origo-bc-appsource-validation` format. Every formal scenario needs Setup, Steps, Expected Results and Cleanup, and an evidence reference. Include publisher, actual packaged version, submission date and validator environment instructions. Record the full source SHA, signed-package SHA256, Foundation package version/hash, BC release/country, compiler/analyzers and actual test counts. Repeat the validator dry-run before handing off. An unrun row stays blocked and cannot be represented as certified.

These files are submission working material, not published product help. Established documentation owners retain the external documentation site. Coordinate corrections, asset publication and help/legal/support acceptance through internal-review. Do not copy Foundation's offer identity or credentials.
