---
title: Attachments build repair and release readiness, 19 October 2026
audience: release-owner
keywords: AppSource, Attachments, verification, release prerequisites
locale: en-US
---

# Attachments build repair and release readiness

| Observed source | Evidence | Result |
|---|---|---|
| Main `f4d524d9bdcfe408701e222ef463b2928f395910`, merged human [PR144](https://github.com/businesscentralal/bc-origo-bifrost-attachments/pull/144) | [Run39240173451](https://github.com/businesscentralal/bc-origo-bifrost-attachments/actions/runs/39240173451) | Default/signing succeeded; Test failed; final cleanup succeeded. Raw JUnit: **313 executed, 311 passed, 2 failed, 0 skipped**. |
| Human repair [PR145](https://github.com/businesscentralal/bc-origo-bifrost-attachments/pull/145), `117ea3b45cb7a31b7fa8e68dd0640a8fe5e5b994` | Existing writer retained; Reginn performs read-only owned-container verification | All three product/test compiler variants have 0 errors / 0 warnings with CodeCop/UICop/AppSourceCop. Native/UI/MCP acceptance remains bound to actual receipts, not this preparation document. |

Reginn (worker-6) retains bounded repair-delivery accountability and submission preparation. Human PR145 already implements the overlapping fixture corrections; its writer is preserved. Architect serializes any implementation handoff. No competing source push is authorized by this inventory. The original issue owners retain their source, checkpoints and remaining acceptance. This inventory does not close their issues or certify an AppSource release.

The original main failures were also reproduced on worker-6 owned container `f0e01dedefcf`: **313 executed / 311 passed / 2 failed / 0 skipped**, 313 distinct methods, BC28.5.54151.56443 W1 and Foundation28.0.3.530. The same two assertions failed. The repair candidate is verified separately.

Windows NAVX verification of the digest-checked **baseline** Default app28.0.0.102 returned `Valid`; SHA256 `1222c41b5f69514c77f78634e2ab542ca545c9039568d87869392374761c3b3e`, source/build match main/run39240173451 and compiled friend grants are empty. Changing one payload byte in an owned copy returned `HashMismatch`; the original hash stayed unchanged and the copy was removed. These are baseline package results, not a signature verdict for a changed source tip.

## Preserve the merged connector decision

[The connector contract](../connector-interface.md) is the shipping design. All registered connectors use Microsoft's interface; Attachments has no concrete connector-app dependency, provider account-table introspection or connector-version pin. The connector owns credentials, provider rules and errors. Protection uses the same registered account GUID, connector, backend and canonical logical path. Separate registrations are separate scopes even when they reach the same physical storage. Reuse a registration for shared attachment files.

Copy and move require a new destination, checked through the connector. This is a preflight, not atomic provider certification. Linked moves through the platform facade remain refused without the optional source-preservation capability. Do not restore removed provider-specific branches or account metadata grants to satisfy historical plans.

## Repair diagnosis and required proof

- CU96225 `SameAccount_MovedLinkKeepsRelativeBase`: the alias row changes are uncommitted before `asserterror`; rollback restores the earlier dispatcher-committed path `Xdir/Xfile.txt`. Commit the intended alias baseline before the expected error. Retain `Xfile.txt` as the expected alias-relative path and verify the same link identity, storage code, base, exact bytes and zero provider writes after refusal.
- CU96236 `Scenario_Interface_ExistenceFailure_RefusesTransfer`: direct unsafe-path calls raise Foundation's helper error collection. A direct test caller must consume that collection as the dispatcher does, or a later connector error can be answered with stale `InvalidParameter`. Preserve `BusinessCentralError` and the injected existence-failure text, and verify no transfer writes, no target and unchanged source bytes. Valid account GUID and paths are already supplied by the interface fixture.
- Reproduce with the complete configured suite, including both codeunits in order; a focused pass alone cannot prove absence of session-context contamination. Preserve restrictive permission enforcement and the non-SUPER check.

## Retained acceptance matrix

| Issue | Retained owner | Integrated source / current evidence | Remaining acceptance and next action |
|---|---|---|---|
| [74](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/74) | Sindri, worker-3 | Current main passes Default compilation; the two observed failures are native assertions. | This bounded repair supplies fresh current-tip compile/native evidence; worker-3 retains broader dependency/build acceptance. |
| [75](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/75) | worker-9 | Link guards and PR144 account/logical-path semantics are merged; CU96225 has the failure above. | Repair fixture transaction proof; owner retains genuine provider effects, recovery and deployed acceptance. |
| [78](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/78) | Reginn / Architect / ori-haraldurb | Analyzer/package tooling is merged. Signing-job success alone proves no NAVX trust verdict. | Verify exact signed Default bytes on supported Windows NAVX SIP/trust; infrastructure owner dispositions the unapplied Pipeline/Signed integration packet from PR140. Do not edit workflow semantics here. |
| [79](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/79) | Andvari, worker-5 | Restrictive interface and Data Exchange tests are merged. | Two genuine restricted identities, effective permissions and dedicated provider acceptance remain with worker-5/identity administrator; LowerPermissions is not two-identity SaaS proof. |
| [80](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/80) | Þráinn, worker-8 | Integrated source exists, but current main Test is red. | After qualifying green integrated candidate, freeze signed app/dependency hashes and run 14 markets, provider, lifecycle, UI/MCP and cleanup matrix. Historical candidates do not transfer. |
| [81](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/81) | Reginn, worker-6 | Working checklist, scenarios and market plan are merged; this reconciliation updates stale connector assumptions. | After #80 QA, freeze formal validator scenarios and execute dry-run. Obtain listing/legal/support/screenshots, registration and baseline evidence through named owners below. |
| [83](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/83) | Architect / root coordinator; Reginn repair | Run39240173451 supplies actual failed-main evidence. | Repair PR with exact-head evidence; Claude verification, Grok clearance, eligible approval, green CI, Architect merge/deploy and Tester UAT. |
| [119](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/119) | worker-5 / worker-7 source; Claude / Tester acceptance | Historical UAT and licence refusals have their own versions/scopes. | Deploy current integrated repair, rerun outstanding owned/provider scenarios; no licence-state writes, mock certification or transferred historical passes. |
| [120](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/120) | worker-10; Architect arbitrates overlap | PR144 removes version pins and provider-specific dispatch. | Source repair does not prove actual Blob/File Share/SharePoint availability or writes at supported versions; dedicated provider owner supplies approved fixtures. |
| [122](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/122) | Sindri, worker-3 | Pure path checks and named nonempty-directory refusal are integrated. Claude's earlier branch receipt explicitly omitted provider-reaching calls. | Reverify actual integrated candidate, nonempty refusal and byte/state readbacks in 1033/1039; no assumed provider certification. |
| [125](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/125) | Retained local-3 source owner via Architect | Root refusal and translations merged; CU96238 passed all 4 methods on failed main. | Current-tip native, bilingual self-seeded root refusal and no-connector-call evidence; same-SHA UAT remains separate. |
| [126](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/126) | Reginn, worker-6 | PR129 and PR144 history are integrated. Apply Gunnar D7 option B: public contract/help stays English; descriptions/refusals follow their scoped language contract. | Exact-candidate 1033/1039/1033 proof and independent Claude acceptance; superseded Icelandic-help AC is withdrawn, never counted passed. |
| [130](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/130) | worker-16 source; worker-10 retained acceptance | Direction/effect regressions CU96229 passed 4/4 at failed main. | Current-tip MCP direction/write-gate proof and actual deployment/UAT, not native-only closure. |

The wider #77 API audit currently has stale inventory coverage/hashes after PR144; Alvíss (worker-4) owns its separate metadata-only repair. Do not regenerate or edit `API-SURFACE.md`, `api-surface-objects.json` or `api-surface-procedures.csv` in this repair.

## Missing release inputs and accountable owners

| Input | Next owner / concrete action |
|---|---|
| Signed final candidate | Architect obtains normal green integrated main Default artifact after merge; #78 verifies its actual signature/trust and source/build/hash. An unsigned repair-branch build cannot be called the signed release. |
| Baseline and registrations | Gunnar / publisher-registration owner supplies first-publish or genuine prior baseline disposition, registered `ori` and both ranges 10035635–10035684 / 70013500–70013549. Source configuration is not registration proof. |
| Dependency compatibility | #78/#80 bind actual Foundation package, installed version/hash and accepted markets/releases. Declared minimum28.0.1.0 does not establish every runtime combination. Old SFTP deployment failures are historical: PR144 removes concrete connector dependencies; confirm actual target before any retry. |
| Provider and legacy access | Architect / provider administrator and lifecycle owner allocate approved dedicated Blob/File Share/SharePoint prefixes, cleanup grants and authentic legacy absent/present/denied inputs. Never reuse customer fixtures or alter credentials. |
| Listing and screenshots | #80 supplies synthetic-data captures at the final candidate; Gunnar / offer owner approves branding, descriptions, captions and actual assets. Source manifest currently has no screenshots. |
| Legal / support / help | Gunnar / legal and support owners confirm actual Attachments coverage, approved revisions and support process; documentation owners confirm published routes. An HTTP200 alone is not legal or support acceptance. |
| New offer | Gunnar / designated offer owner separately authorizes creation and supplies genuine Attachments offer/app mapping. Keep productId empty; never copy Foundation's ID. |
| Publication | Claude owns release preparation. Gunnar must approve on the decisions page **before every publish**. No Create release, Publish To AppSource, GoLive or Partner Center write is authorized by this repair. |

The standards snapshot is `ac05e88ab51ed4c9bbfb843508fc2484afe5ec8f`, synchronized 3 October; no fresh synchronization is claimed. Preserve parked #20/#21/#24/#25/#26 without action. Retain owned development resources until the required same-SHA deployment/UAT and issue-closure disposition; stop idle retained resources and verify eventual authorized cleanup.
