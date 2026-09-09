# Origo BC — PR Gateway Report

```
╔══════════════════════════════════════════════════════════════════╗
║           Origo BC — PR Gateway Report                           ║
║           Extension : Bifrost Attachments v28.0.0.0              ║
║           Customer  : Origo (AppSource, Bifröst portfolio)       ║
║           Date      : 2026-09-07 03:05                           ║
║           Tier      : Standard (AppSourceCop.json, no stories/)  ║
║           Branch    : feature/bifrost-hnitbjorg-migration → main ║
╠══════════════════════════════════════════════════════════════════╣
║  LAYER 1 — Automated Script (23 checks)                          ║
║  Files scanned: 63     Passed: 14/23     Failed: 9               ║
║  After agent triage: 9 real findings fixed, 0 open,              ║
║                      248 dismissed as false positives            ║
╠══════════════════════════════════════════════════════════════════╣
║  LAYER 2 — Agent Deep Checks         Result                      ║
╠══════════════════════════════════════════════════════════════════╣
║  1.  AL Compiler                     ✅ Pass  (0 err / 0 warn)   ║
║  2.  Object Naming — Prefix          ✅ Pass                     ║
║  3.  Object ID Ranges                ✅ Pass                     ║
║  4.  SetLoadFields — Exceptions      ✅ Pass                     ║
║  5.  Breaking Change Guard           ⏭ Skip (initial phase)     ║
║  6.  app.json — Semantic             ⚠️ Pass w/ 2 deviations     ║
║  7.  CHANGELOG & README Quality      ✅ Pass                     ║
║  8.  HTML Help Pages                 ⚠️ Deviation + 1 warning    ║
║  9.  Documentation Generation        📝 Done                     ║
║  10. Unit Tests                      ✅ Pass  (61/61 × 2)        ║
║  11. Story-Doc Consistency           ⏭ Skip (no stories/)       ║
║  12. Logic Review                    🔍 4 findings               ║
║  13. What I Couldn't Check           🔍 4 gaps noted             ║
║  14. Role Coverage                   ✅ Pass                     ║
║  15. Platform Integration            ⏭ Skip (not standards repo)║
╠══════════════════════════════════════════════════════════════════╣
║  Overall : ✅ 8 passed  ❌ 0 failed  ⚠️ 2 warnings  ⏭ 3 skipped ║
╚══════════════════════════════════════════════════════════════════╝
```

Target branch `main` detected from `.claude/CLAUDE.md` (`Default branch: main`) and confirmed
against the open PR #1.

---

## Layer 1 — Automated scan, with agent triage

The script reports 9 failed checks. Every finding was read against the source; the table below
records what was real and what was dismissed, with the reason.

| Check | Raw | Real | Disposition |
| --- | ---: | ---: | --- |
| `set_load_fields` | 17 | 7 | 7 fixed. The remaining 10 are `FindSet(true)` / `Get` reads that are followed by a write or handed to a base-app method (`IncomingDocument.AddAttachmentFromStream`), a `RecordRef`, a `JsonObject.Get`, or a blob read where `SetLoadFields` does not apply. |
| `read_isolation` | 4 | 2 | 2 fixed (`Storage.Account.List` scan, take-over permission scan). The other two are update paths (`FindSet(true)`, session lock) where the default isolation is the correct one. |
| `xml_doc_comments` | 149 | 0 | All 149 are `internal` procedures implementing `Msg Interface ori` or `Storage Connector ori`. The interface carries the contract documentation; every object itself is documented. This is the pattern the whole Bifröst portfolio uses. |
| `caption_translation` | 23 | 0 | All 23 are the `Storage Msg Type ori` enum captions, `Locked = true` by design — they are the public wire contract and must not be translated. |
| `one_statement_per_line` | 62 | 0 | Every hit is a procedure signature with several parameters; the scanner counts the parameter separator `;` as a statement separator. |
| `hardcoded_values` | 2 | 0 | The legacy app id in `Storage Takeover ori` (the take-over cannot look it up) and the notification GUID on `Attachments Setup ori` (the standard BC notification pattern). |
| `modernization` | 2 | 0 | `TaskScheduler` matched as a legacy keyword although the code uses the modern Task Scheduler; `NAS` matched inside a longer word on `Storage Card ori`. |
| `page_code_minimal` | 3 | 0 | The three hits are wizard step transitions on `Storage Setup Wizard ori` (`CurrentStep += 1; OnStepEnter(); UpdateControls();`). Step state belongs to a wizard page. |
| `global_variables` | 1 | 0 | `Storage Help Builder ori` holds 17 globals because it *is* the builder that assembles one help document; the alternative is passing 17 parameters. |

---

## Check 6 — app.json: two approved deviations

Everything mandatory is present and semantically correct: id matches `.claude/CLAUDE.md`,
publisher `Origo`, version `28.0.0.0`, `target: Cloud`, application/platform `28.0.0.0`,
`idRanges` `10035635–10035684` matching both the registry and every object in the app, and
`applicationInsightsConnectionString` set (the modern replacement for `applicationInsightsKey`).

Two values deviate deliberately:

- ⚠️ **`EULA` still points at the Cloud Events Terms of Use PDF**
  (`Origo_BC_Cloud_Events_Terms_of_Use_-1-.pdf`). Carried over from the source app.
  **Needs a decision before AppSource submission** — a Bifröst EULA has to be published, or the
  existing one deliberately reused.
- ✅ **`help` and `contextSensitiveHelpUrl` use `businesscentralal.github.io`** instead of
  `bifrost.origo.is`. Approved: the DNS record does not exist yet, and the URLs move with the
  record.

---

## Check 8 — Help pages: approved deviation, one open dependency

The repository holds no `Help/` or `docs/` folder — approved deviation, all public documentation
lives in `businesscentralal/bifrost`. Every `ContextSensitiveHelpPage` slug was resolved against
that site repository:

| Slug | Pages | en-US | is-IS | Site branch |
| --- | --- | :---: | :---: | --- |
| `hnitbjorg-setup` | Attachments Setup ori, Storage Conn. Part ori | ✅ | ✅ | ⚠️ `setup-pattern-help` only |
| `storage-setup` | Storage Setup ori, Storage Setup Wizard ori | ✅ | ✅ | `main` |
| `storage-card` | Storage Card ori | ✅ | ✅ | `main` |
| `storage-account-lookup` | Storage Account Lookup ori | ✅ | ✅ | `main` |

⚠️ **`hnitbjorg-setup` is not on the site's `main` branch yet.** Both language versions exist and
declare `id: hnitbjorg-setup` in their front matter, but only on branch `setup-pattern-help`.
Until that branch merges and the site rebuilds, the Help button on the new setup page and its
connection part resolves to a 404. Merge the site branch with — or before — this PR.

---

## Check 9 — Documentation

- `CHANGELOG.md` — version heading moved to `## [28.0.0.0] - 2026-09-07`; added a
  `### Changed (2026-09-07)` entry (restore ordering, narrowed reads) and a
  `### Security (2026-09-07)` entry (relative path segments rejected). Also carried over from the
  interrupted run: the stale `origopublic.blob.core.windows.net` help URLs were removed and the
  two `#### Added` / `#### Changed` headings were promoted to `###` so the Keep-a-Changelog
  category levels are consistent.
- `README.md` — rebuilt against the mandatory template. All ten sections present and in order
  (Header → Overview → Functional Flow → Benefits → Logic Flow → Setup & Configuration →
  Example Scenario → Objects → Dependencies → … → Documentation). The Objects table was
  cross-checked field by field against the source: **63 objects, 63 rows, no id in the table that
  is not in `app/src`, and none in `app/src` missing from the table.** Dependencies match
  `app.json`. Copyright year 2026. The stale `hnitbjorg.app` example in the compile command was
  corrected.
- ⚠️ Minor: the file ends with the COSMO Alpaca `<!-- AUTO-UPDATE-START -->` block, which carries a
  second `# COSMO Alpaca AL-Go AppSource App Template` H1. That block is rewritten by AL-Go's
  template update, so it was left alone.

---

## Check 10 — Unit tests

| Container | Company | Codeunits | Tests | Passed | Failed |
| --- | --- | ---: | ---: | ---: | ---: |
| `bc28-is` (`f068155f0c39dev`) | CRONUS IS | 5 | 61 | **61** | 0 |
| `bc28-w1` (`f089d7daffb9dev`) | CRONUS International Ltd. | 5 | 61 | **61** | 0 |

App and test app were rebuilt and published to both containers with `SchemaUpdateMode=Synchronize`
before the runs. The w1 publish needed a retry — the first two attempts returned
`422 … another service is currently modifying the state of extensions`.

Coverage added by this change (4 tests, `Storage Connector Tests`):

- `RelativePathSegmentIsRejected` — `../../secret.txt` through `Storage.File.Get`
- `RelativePathWithBackslashesIsRejected` — `reports\..\..\etc` through `Storage.Directory.Create`
- `CurrentDirectorySegmentIsRejected` — `docs/./hello.txt` through `Storage.File.Exists`
- `DotsInsideAFileNameAreAccepted` — `docs/my..archive.v1.txt` still creates (the guard rejects
  whole segments, not dots)

Happy path, invalid input and edge case are all covered for the new behaviour.

**Stale test handler resolved.** `BifrostSetupPage_ExposesOnlyTheAppsAction` still declared
`[HandlerFunctions('NotificationHandler')]` after the "Allow HttpClient Requests" notification
moved off the shared Bifröst Setup page onto `Attachments Setup ori`. Nothing raised a
notification any more, so the test failed with an unexecuted handler. The attribute was removed
and the reason recorded in the test body. Both container runs confirm the fix.

---

## Check 12 — Logic review

```
╭──────────────────────────────────────────────────────────────╮
│  What this change does:                                      │
│  Closes a path-traversal hole in the storage message types,  │
│  reorders the irreversible step in Attachment.Restore, and   │
│  narrows the hot record reads.                               │
╰──────────────────────────────────────────────────────────────╯
```

| AC | Criterion | Result |
| --- | --- | --- |
| 1 | A caller cannot address anything outside a connection's `Base Path` | ✅ |
| 2 | Legitimate names containing dots keep working | ✅ |
| 3 | Rejection is reported as `status = Error`, not an exception | ✅ |
| 4 | Restore never destroys the only copy of a file | ✅ |
| 5 | Narrowed reads do not change what the code sees | ✅ |

The guard sits in two layers: `Storage Request Mgt ori.CheckPath` answers the message types with a
proper error envelope, and `Storage Ext File Impl ori.ResolvePath` re-checks every path that
reaches the production connector — so routes that build a path internally (attachment offload
folders, upload target folders) are covered too, not just the ones a caller names directly.

**Findings (4):**

- 👁 **Blindspot — Impact Radius.** The `ResolvePath` guard also applies to paths that were
  *stored* by the published *Origo Cloud Events Storage* app and copied into
  `Storage Attachment Link ori` by the take-over. A legacy `Storage Path` containing a `.` or `..`
  segment would now fail to serve or restore. Very unlikely — the legacy app built its paths the
  same way — but it is a behaviour change on inherited data that no test here can reach.
  *Decision needed: accept, or add a one-time scan in `Storage Takeover ori`.*
- ℹ️ **Trust — untested install path.** `Storage Takeover ori.TakeOverAccessControl` now uses
  `SetLoadFields` on the system table `Access Control`. The take-over runs only on a first install
  next to the published legacy app, which the suite cannot exercise. The gain is a handful of rows
  once per company; if partial records ever misbehave on that table, the cost is a failed install.
  *Flagged rather than reverted — call it if you want it dropped.*
- ⚠️ **Robustness (pre-existing, out of scope).**
  `Storage Attachment Mgt ori.FindLinkedStoragePathInDirectory` reads every link row for a storage
  code and does the directory-prefix test in AL. `Storage.Directory.Delete` therefore gets slower
  in a straight line with the number of offloaded attachments. A `SetFilter("Storage Path", '%1*')`
  would use the existing `("Storage Code","Storage Path")` key — but the directory path is
  caller-supplied, so it needs filter-character escaping first, which is a change of its own.
- ℹ️ **Comment corrected.** The rationale comment on the reordered `Restore` claimed a failing
  remote delete "leaves an orphan blob behind". It does not: the delete is inside the task's
  transaction, so a failure rolls the whole restore back and the attachment simply stays offloaded
  with its remote copy intact. The comment and the CHANGELOG entry now say that.

---

## Check 13 — What I couldn't check

- **Skipped:** Check 5 (no published baseline — `AppSourceCop.json` has no `version`, the app is
  unreleased), Check 11 (no `stories/` folder), Check 15 (not the standards repository).
- **Limited:** `AppSourceCop.json` has no ruleset file, so AppSourceCop runs with default actions;
  command-line `alc` does not raise AS0011 (mandatory affix), so the ` ori` suffix was verified by
  hand across all 63 objects instead — AL-Go CI remains the real gate.
- **Not exercised:** the data take-over (`Storage Takeover ori`) — it fires only on a first install
  beside the published Cloud Events Storage app. The unit suite cannot reach it, in either
  container.
- **Needs a human:** the two open decisions — the EULA URL, and whether the `hnitbjorg-setup` help
  page ships from the site's `setup-pattern-help` branch before this PR merges.

---

## Check 14 — Role coverage

`BIFROST Attach ori` (assignable) and `Storage Full ori` (extending Foundation's
`BIFROST Full ori`) carry identical grants: the 4 tables at `RIMD`, all 43 codeunits at `X`, all
6 pages at `X`. The three objects added by the setup migration — `Attachments Setup ori` (10035677),
`Storage Conn. Part ori` (10035678) and `Storage Upload Purge ori` (10035679) — are in both lists.
Every page is paired with its `tabledata`. No gap.

---

## Verdict

```
✅  No blocking failures. The branch is ready to merge, with two open decisions:
    1. app.json EULA still points at the Cloud Events Terms of Use PDF.
    2. The `hnitbjorg-setup` help page lives on the site branch `setup-pattern-help`
       and must reach businesscentralal/bifrost `main` or the Help button 404s.
```

*AI-assisted review. It cannot catch domain rules that are not written down anywhere, and the
inferred acceptance criteria above are a reading of the code, not a specification.*
