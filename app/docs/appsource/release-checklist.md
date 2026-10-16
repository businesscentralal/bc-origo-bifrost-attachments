---
title: Collect Attachments release evidence
audience: release-owner
keywords: AppSource, Attachments, Partner Center, release gates
locale: en-US
---

# Collect Attachments release evidence

**Preparation, not release certification.** Source observations are recorded in [source-inventory.json](source-inventory.json). Final release evidence must identify one accepted signed candidate; a merged PR, compile pass or successful deployment alone does not close #81.

## Select and prove the candidate

- [ ] Architect identifies the integrated main SHA under [decision1792179827](https://bifrst-group.slack.com/archives/C0C0XM70YF8/p1792179827684749): #72, #122 repair `dffe555`, PR127, PR128 and PR129; PR129 may be excluded only as that decision specifies. Build87/b66d1f2 is not the candidate.
- [ ] Main Default and Test are green with nonzero executed tests, zero failures/skips and a signed no-friend Default Apps artifact. Record full SHA, run/attempt/artifact IDs, package version/SHA256 and source/build metadata.
- [ ] #78 / Reginn and ori-haraldurb reconcile the actual installed Foundation variant/hash against accepted input and verify Windows package signature trust. Compiler success or matching package size is insufficient.
- [ ] #80 / Þráinn records the exact acceptance matrix: 14 markets, 36 provider cases, 10 lifecycle cases, Web Client UI and public MCP in LCIDs1033/1039; retain actual counts and sanitized evidence. No mocks or other candidates' receipts substitute for this.

Historical [build87 receipt](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/80#issuecomment-6222103811) at `b66d1f21370e7cd4c54edfc23fd4ff9a6b6d6005` reports app/test compile0errors/0warnings and 280executed/280passed/0failed/0skipped, package28.0.0.87. Existing Test-lane suppressions are disclosed there; this is not a no-suppression certification. It is historical input, not evidence for the future integrated candidate. PR128 merged16October; PR127/#122 integration and PR129 disposition still require current receipts.

## Confirm identity, markets and dependencies

| Item | Source evidence | Required release evidence / owner |
|---|---|---|
| Identity | Bifrost Attachments; Origo; `672df32a-a0c5-4a22-b591-0efa38023e95` | #80: signed manifest and listing agree |
| Version | Source28.0.0.4 | #80: actual packaged and deployed version, never inferred from source |
| BC floor | Application/platform28.0.0.0, runtime17.0, Cloud | #80 / Architect: actual supported build/country matrix. CI28.5 success does not prove the declared BC28 floor with newly required connector versions |
| Foundation | `7505e808-6e52-4b96-a328-82573391297a`, Origo, source minimum28.0.1.0 | #78/#80: accepted package version/hash/source, actual runtime hash and signature trust; historical523 is not the active pin |
| Connectors | Production External File Storage and registered File Accounts; PR127 proposes four explicit Microsoft dependencies at28.5 | PR127 owner / Architect / #80: final merged names/IDs/versions/hashes, runtime compatibility and availability in every market. SFTP dependency does not add SFTP to the approved three-provider scope |
| Markets | IS,GB,DK,NO,SE,FI,DE,FR,NL,AT,CH,IE,PT,ES | #80: [14-row evidence plan](market-evidence-plan.md); Gunnar/offer owner: separately authorized Partner Center comparison |
| Languages | en-US/is-IS | #80: actual UI and public MCP1033/1039 at candidate; #72/PR129 disposition reflected without promising unshipped behavior |
| Registered suffix and both ranges | `ori`;10035635–10035684;70013500–70013549 | Gunnar / designated registration owner via Architect: authoritative allocation/registration evidence; #77 source audit alone is insufficient |
| Historical validation baseline | Not established by the no-offer decision | Gunnar / designated publisher owner: baseline identity and applicable validation history, or explicit no-baseline evidence |
| New offer and genuine ID | 6October no-offer decision; `deliverToAppSource` unconfigured | Gunnar / offer owner: future separately authorized creation and genuine app/offer mapping. Never invent/copy an ID or create an offer under #81 |

## Collect operator materials and access

| Material | Working input | Acceptance / named owner |
|---|---|---|
| Listing | Manifest describes Azure Blob Storage, Azure File Share, SharePoint, uploads and offloading | Offer owner: approve name, summary, description, categories and languages matching proven shipping capabilities |
| Logo | Source250×250 PNG; SHA256 `0f9185810ff29e9c77c7258d7b7bd3a51f5fcaa2bed0bcbf4288fd673fc0cc60` | Offer owner: actual rights/branding and current required asset variants |
| Screenshots | Manifest has no screenshots | #80 provides exact-candidate EN/IS synthetic-data captures; offer owner approves rights/captions; remove secrets and personal identifiers |
| Help | Manifest product URL `https://docs.bifrost.origo.is/en-us/attachments/`; context pattern `https://docs.bifrost.origo.is/{0}/help/attachments/` | Documentation owners / Architect: current candidate's page routes, translations, redirects/accessibility and publication receipt. The13October404 observation is historical, not a current outage claim. #81 does not edit their site |
| Legal | Manifest EULA/privacy use shared `/en-us/licensing/eula/` and `/en-us/licensing/privacy/` routes | Gunnar / legal owner: actual Attachments and external-file-processing coverage, accepted revision and accessibility; HTTP status alone is insufficient |
| Support | Manifest publisher website `https://www.origo.is/` | Gunnar / support owner: approved contact/URL, response process and dependency guidance |
| Provider access | Dedicated Blob/File Share/SharePoint account, root, quota and availability window per validator | Provider owner through Architect: genuine constrained access, secure credential references and revocation/cleanup ownership; no secrets in artifacts |
| Restricted identities | Separate non-SUPER setup, usage and denied actors; genuine independent sessions where required | #79 / designated identity owner: approved secure allocations and effective grant union. AL LowerPermissions and seeded audit fields do not prove distinct SaaS identities |
| Activation and transport | Foundation public API/license prerequisites | #79/#80: actual supported activation/transport/roles on candidate. No backend EULA/trial/licence writes or harness-as-shipping proof |

## Deliver scenarios and close acceptance

- [ ] Reginn completes preparation now; after #80 passing candidate QA, generates independently executable `AppSource-UserScenarios.md` and freezes tested payloads/UI expectations. Each feature and installation/permission/error/uninstall category gets Setup/Steps/Expected Results/Cleanup.
- [ ] Execute [validator smoke](validator-smoke-script.md) on validator-owned sandbox with self-created fixtures, exact app/dependency provenance and independent readback; retain actual executed/passed/failed/skipped counts. Dry-run remains0executed until performed.
- [ ] Developer-owned fixture cleanup verified after each scenario, including failure paths. Record development container name/id; retain same container for amendments until Tester postdeploy UAT and issue closure, then verify owned deletion. Do not request UAT data cleanup.
- [ ] Any new candidate compiles product and test0errors/0warnings before compiled verification-only publication. Read back branch/fullSHA/immutable commit using `verify-github-candidate.cjs`. Publication is not PR readiness.
- [ ] Before PR creation/review push/undraft: full configured suite0failed/0skipped, UI, applicable self-seeded MCP and cleanup at that exact tip. Disclose inherited failures/suppressions; do not create exclusions or weaken checks.
- [ ] Claude current-head independent verification on its assigned bc28-w1, no open amendments; Grok Reviewer current-fullSHA clearance; eligible non-author approval; meaningful green required checks. Use canonical guarded green-pr-handoff when genuinely ready. No retired internal-review gate.
- [ ] Architect alone merges with merge commit and controls same-SHA deployment; Bifröst Tester alone performs postdeploy UAT. Preserve delivery tracking after auto-close/merge until actual acceptance and owned-container closure.
- [ ] Secretary genuine START/STOP and ACK retained; posting/process exit is not acknowledgement or delivery.
- [ ] Offer/listing/legal/support/registration/dependency evidence accepted by named owners; genuine ID mapping supplied only after separately authorized creation. Gunnar approval before every publish. Nothing here submits or publishes the offer.

The internal working location is approved; external help stays with its owners. Foundation is an evidence-discipline reference, never a source of Attachments identity, credentials or release approval. Optional parked roadmap #21/#23–#26 and historical personal cleanup #20 remain outside this scope.
