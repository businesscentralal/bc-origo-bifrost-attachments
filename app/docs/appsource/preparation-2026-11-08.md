---
title: Reconcile Attachments submission preparation on 8 November 2026
audience: release-owner
keywords: Attachments, submission, candidate, signature, offer, evidence
locale: en-US
---

# Reconcile the preparation with current source

| Source fact | Inspected value | Evidence boundary |
|---|---|---|
| Source | `842f44e4934227b8f272b289eeb5959e2e6888c7` | Published main read back on 8 November; not a nominated final QA candidate |
| App | Bifrost Attachments, Origo, `672df32a-a0c5-4a22-b591-0efa38023e95` | `app/app.json` |
| Source version | `28.3.2.0` | Package and installed versions require their own receipts |
| Foundation minimum | Product `28.0.11.669`; test `28.0.10.632` | Distinguish manifest floors, compiler inputs and installed package hashes |
| BC | Application `28.3.0.0`, platform `28.0.0.0`, runtime `17.0` | Does not prove every supported country/build |
| Countries | IS, GB, DK, NO, SE, FI, DE, FR, NL, AT, CH, IE, PT, ES | `AppSourceCop.json` and market CSV; 14 declarations, no new country passes |
| Offer configuration | `ae26bc25-7547-42ec-a1b7-c55e3b830569`; `continuousDelivery: false` | Merged [PR176](https://github.com/businesscentralal/bc-origo-bifrost-attachments/pull/176); no fresh Partner Center lookup or publication approval |
| Listing inputs | `listing/description.html`, `description.md`, `product-sheet.pdf`, `logo-216.png`, three screenshots | Existing draft assets; availability does not prove rights, approval or final-candidate accuracy |
| Manifest screenshots | Empty list | Does not mean the listing folder has no screenshots |

[Inspect the immutable source](https://github.com/businesscentralal/bc-origo-bifrost-attachments/tree/842f44e4934227b8f272b289eeb5959e2e6888c7). The source inventory is regenerated from committed bytes. No application, test, workflow, delivery setting, market or identity is changed by this reconciliation.

## Keep historical receipts attached to their own candidates

| Receipt | What it establishes | What remains unproved |
|---|---|---|
| [20 October build113](candidate-2026-10-20.json) | Its recorded compiler/test counts and Windows trust/tamper result, on `c30c2254bf953ed2e6f90fdf080dfb216bea799f` only | Current source, dependencies, package, provider/market QA |
| [3 November build136 signer record](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/81#issuecomment-6612490143) | Linux cryptographic checks and Origo hf certificate thumbprint `2AD5FF188D0B22858A2813817A929BCC1EC03E4A` on package SHA256 `ec54c41d0e801263e42d119773569eb578097971b859908d1f853f457178678b`, source `72d441c5fabcba4262a1c0a723d34ac27a2158e0` | Windows NAVX Valid/HashMismatch; any newer signed artifact |
| [4 November partial country matrix](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/80#issuecomment-6619184813) | Reported country compiles on a different unsigned candidate | Signed-package country deployment/runtime, final candidate, provider/lifecycle certification |

The signed-package check now belongs to #81 under [Gunnar's 3 November disposition](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/81#issuecomment-6610613002). Record the selected artifact's signature and thumbprint using the [release checklist](release-checklist.md#record-the-signed-package-before-submission); do not transfer a historical signature verdict to new bytes.

## Complete the remaining acceptance with the named owners

| Acceptance | Preparation present | Remaining evidence / next owner |
|---|---|---|
| AC01 | Twelve-family scenario plan with independent fixtures and cleanup | #80 retained QA owner and Tester complete final-candidate QA; then the #81 developer writes atomic Setup / Steps / Expected Results / Cleanup scenarios |
| AC02 | Full source observation and explicit historical receipt boundaries | Architect nominates the final candidate; #80 supplies proven package/dependency/UI/message evidence before formal documents freeze it |
| AC03 | Fourteen-country list, current manifests, configured offer ID and draft listing assets | Gunnar/designated offer, legal, support and registration owners confirm current mapping, rights, URLs, supported markets and approvals; provider owners provide secure validator access |
| AC04 | Manual owned-sandbox smoke script and local receipt checker | After QA, the #81 developer runs it on an owned sandbox, records actual counts and verifies owned fixture cleanup |
| Signed package | Per-artifact evidence checklist and preserved historical receipts | #81 developer records the nominated artifact's hash, signer/thumbprint and Windows trust/tamper receipt; certificate-owner disposition remains with Gunnar |

The [4 November QA check](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/80#issuecomment-6626908886) leaves #80 open. The [5 November submission hold](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/81#issuecomment-6666652824) permits material preparation only. Neither a draft listing, repository offer ID nor a green CI run supplies permission to submit or publish.

Run `python3 tools/generate_source_inventory.py --check` to check committed source facts. `python3 tools/validate_submission.py` retains its explicit configured-offer approval gap. Do not weaken that gate or remove the existing configuration to make the report green. No validator execution or certification pass is claimed by this preparation.
