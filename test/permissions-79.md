# Verify story79 permission boundaries

| Surface | Actor role and explicit prerequisites | Source regression | Acceptance status |
|---|---|---|---|
| Foundation baseline | Actual `BIFROST API ori`, same authenticated caller/company; operator-provided usable license/EULA state | `Help.WhoAmI.Get` precedes each lowered actor phase | Runtime pending; internal dispatch does not prove external API licensing |
| Storage setup card | Actual `BIFROST Attach ori` plus Foundation baseline | Card field change and fresh persisted readback | Authored; not executed |
| Setup denial | Source-derived `Storage79 Setup ori` replaces Attach; setup R, no I/M/D | Card refusal; independent insert/modify/delete attempts; original setup readback | Authored; not executed |
| Account discovery | Actual Attach plus Foundation baseline | `Storage.Account.List` must return the seeded X79 row | Authored; not provider selection proof |
| Real account selection/Test Connection | Actual Attach, installed connector's documented role, licensed provider account | Actual card account action and real registered account | Blocked on exact connector fixture/roles/access; mock account IDs are not substitutes |
| File/directory operations | Actual Attach plus Foundation baseline; existing in-memory connector | Create/get/exists/list/copy/move/delete; bytes and deletion readback; invalid content leaves no file | Authored; supplemental mock backend only |
| Upload begin/append/status/commit/abort | Actual Attach plus Foundation baseline; current genuine session | Byte assembly, persisted committed/aborted state, chunk deletion, empty-commit refusal | Authored; not executed |
| Native creation and CommitToRecord | Actual Attach plus Foundation baseline; Customer R, Document Attachment RIMD | Public dispatch plus native content/row readback | Authored; verify effective base-app/media prerequisites at runtime before declaring minimum role |
| Missing native source read | Actual Attach and native target fixture, no Customer R | Valid CreateForRecord payload must refuse with PermissionDenied; target/source readback | Authored; response nextStep requirement intentionally retained |
| Missing native target mutation | Actual Attach, Customer R and Document Attachment R, no native IMD | Buffered CommitToRecord must refuse, retaining session/chunk bytes and no attachment | Authored; not executed |
| Offload/open/restore | Actual Attach, Foundation baseline and native baseline | Dispatch, base-app content-export trigger, link/native/mock bytes and deletion readback | Authored; preserves #11 native contract hold and #75 ownership |
| Missing link mutation | Source-derived `Storage79 Link ori` replaces Attach; link R only, native mutation granted | Valid offload must refuse before native clear/remote write; native/link/mock readback | Authored; not executed |
| Data Exchange discovery | Actual `BIFROST DataExch ori` plus Foundation baseline | Seeded Definition.Get/List, Type.List, Entry.Get/List; entry blob and full graph readback | Authored; only six registered discovery surfaces |
| Each discovery read omitted | Derived DataExch fixture replaces advertised role; exactly one of eight table reads omitted | Verify all eight effective read preconditions, dispatch seeded graph, persisted graph/blob readback | Eight authored regressions; not executed |
| Registered Type.Set/Import.Run/Export.Run refusal | Actual DataExch + Attach + Foundation API roles; all discovery reads granted, every Data Exchange mutation absent | Valid import/export definitions and complete requests; type/graph/blob/entry-count and mock source/target readback | Three authored regressions; not executed; #82 retains product ownership |
| Definition.Export and unreferenced Definition.Delete | Exact declared baseline roles, including any required Bank Export/Import Setup read | Additional allocation/prerequisite disposition and actual dispatch | Remaining coverage gap through internal-review; no unrelated earlier denial may count |
| Two actual SaaS identities | Separate operator-approved online sandbox sessions A/B, same company/license and real protected connector access | A begins/appends; B cannot see/status/append/abort/commit/CommitToRecord; A retains control; source/target/provider readback | Genuine access blocker; no audit-field or LowerPermissions impersonation |
| Provider read/write denials | Exact licensed connector package/roles and isolated X-prefixed backend root | Real success and denied operations with remote source/target readback | Genuine access blocker; no synthetic provider certification |
| Legacy takeover denial, #76 | Immutable supported legacy package; actual denied source read/Access Control write; real install/upgrade execution context | Worker-10 owns lifecycle/schema tests 96209/96210 and fixture manifest | Coordination requested through internal-review; legacy access hold remains |

## Run the supplemental AL suite

1. Merge the verified canonical PR84 repair normally when available. Preserve all baseline tests and sibling regression allocations. PR87 is a held donor; PR91 belongs to the pipeline owner.
2. Build app and test app with actual analyzers on supported BC28 and the applicable BC29 CI path. Both must produce 0 errors and 0 warnings. The current source still fails; no baseline waiver applies.
3. Use the approved Foundation package **28.0.2.523**, source `336b91d9fff11b71ae5cd75dee08186d4218bf07`, run `37544940349` attempt 2, SHA256 `5901bebe66b44e91ed6110620e62ee45d122ba9e0378dcfda4aeef4d00d3ae0f`, zero friend grants. Verify archive/package/manifest provenance independently. Product and test dependency floors remain **28.0.1.0**.
4. Verify exact Microsoft test-library symbols. The test app explicitly depends on Permissions Mock. `Library - Lower Permissions.SetExactPermissionSet` avoids the extra All Objects/Test Tables/D365 Basic assignments of Push/Set. The test library must actually be running: every actor phase checks `HasChangedPermissions` and absent Customer mutation. Missing prerequisites fail rather than early-pass.
5. Run all preserved baseline tests plus codeunit **96218 Storage 79 Perm Tests ori** on one owned disposable GitHub-origin COSMO W1 environment. Calls remain serial. Record full source SHA, deployed app/test/compiler/analyzer/Microsoft/Foundation hashes and actual pass/fail/skipped counts. Run the real TestPage surface and authenticated ephemeral Web Client verification. Verify environment deletion.
6. Record genuine two-identity/provider/lifecycle results separately after operator access release. AL role simulations cannot satisfy those acceptance rows.

## Inspect the exact permission union

| Test set ID | Name | Purpose |
|---|---|---|
| 96218 | Storage79 Test ori | Enumerated test/assertion/lowering/mock codeunit execution; no production tabledata or wildcard |
| 96219 | Storage79 Setup ori | Main's Attach grants with only setup IMD removed |
| 96220 | Storage79 Source ori | Native attachment RIMD, no Customer read |
| 96221 | Storage79 Target ori | Customer R and native attachment R, no native mutation |
| 96222 | Storage79 Link ori | Main's Attach grants with only link IMD removed |
| 96227–96234 | Storage79 Entry/Column/Def/Field/FldMap/Line/Map/Type ori | Main's DataExch grants with one named table read removed |

The positive native actor adds Source + Target to the actual Attach/API roles to supply only the enumerated native tabledata baseline. These are test-app fixture sets, not advertised production roles. Setup/Link/discovery omission fixtures replace the original role; adding the original back would invalidate the denial. The observer phase calls `StopLoggingNAVPermissions` to restore the runner's original permissions for fresh readback. It supplies no evidence of actor access. Test helpers have no elevated `Permissions`/`InherentPermissions` on protected product tables.

The actual Foundation **BIFROST API ori** package grants `table * = X` and `codeunit * = X` and includes LOGIN/Changelog - Read. This is the advertised dependency role's existing union, not a test-added wildcard. Consequently Attach's missing explicit execute grant for contract codeunit **70013500** does not alone prove an effective runtime defect. The shared-help regression retains the advertised union and adds no experimental contract grant. Reserved test permission IDs 96223/96224 are intentionally unused; no connector omission role is invented without exact package semantics.

No source test rewrites identity fields, provisions membership/credentials, activates unregistered Data Exchange handlers, repairs product grants, or changes #11's held native behavior. Optional #21/#23–#26 and personal #20 are excluded.

## Retain real blockers and ownership

| Gate | Named owner | Resume evidence |
|---|---|---|
| Product/test compile repair | Worker-3, canonical PR84 | Verified usable current-tip repair; normal merge into this branch and exact-input analyzer builds |
| Immutable Microsoft/Foundation inputs and guards | Worker-6, #78 | Protected ready-input manifest, actual compiler/symbol hashes and required guard repairs |
| Two licensed restricted online identities, connector/provider and legacy access | Gunnar, operator; administrator/verifier custodians to be explicitly designated | Approved disposable online sandbox/company, protected per-identity MCP paths, delegated SaaS UI verifier, exact connector roles/license and isolated backend root, immutable legacy package |
| Legacy lifecycle denial | Worker-10, #76/PR85 | Actual owner fixture/allocation receipt and versioned supported schema/lifecycle evidence |
| Shipped Data Exchange refusal implementation | Worker-9, #82 | Own scoped current-tip behavior and verification; #79 does not take over its product files |
| Publication, infrastructure and explicit release | Existing respective owners | Their recorded release; source preparation releases none of these holds |

At source preparation, **0 runtime tests have executed**. Authored tests, static checks and a draft PR are not proof that #79 is done. Preserve failed results, exact-SHA CI continuation and these holds until every required gate is verified.
