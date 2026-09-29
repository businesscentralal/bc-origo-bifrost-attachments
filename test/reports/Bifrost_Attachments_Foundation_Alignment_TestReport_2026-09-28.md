# Bifrost Attachments - Foundation alignment test report (2026-09-28)

Internal. Branch `feature/foundation-message-type-conformance`.

## What was tested

The alignment of the 23 storage message types with Bifröst Foundation's new message-type behaviour:
structured errors (Foundation #138, #135, #136), discovery keywords (#144), the help conformance rules
(#146), and chunks of up to 240 MiB.

## Build

- Foundation symbols: built locally from `origo/docs/142-help-drift`, the top of the open stack
  #161 → #162 → #164 → #165 → #166 → #167 → #168 → #169 on top of main.
- App and test app compiled with CodeCop, UICop and AppSourceCop: **0 errors, 0 warnings**.
- Icelandic: `Update-IcelandicXlf.ps1` wrote 236 targets from `is-IS=` comments, 3 kept, **0 without Icelandic**.

## Unit tests - bc28-is (Foundation 28.0.1.0 dev build)

| Codeunit | Result |
|---|---|
| 96200-96210 (existing 8 codeunits) | all passed |
| 96211 `Storage Msg Conformance Tests` (new) | 8/8 passed |
| 96212 `Storage Error Response Tests` (new) | 16/16 passed |
| **Total** | **10 codeunits, 95 tests, 95 passed, 0 failed** |

The first run found two defects in this change, both fixed before the green run:

1. `PathIsSafe` converted from an empty string instead of `'\'` (a scripted edit dropped the backslash);
   53 tests failed on it.
2. `LoadContent` took the connector interface by value; an unassigned interface (inline or copied
   content) cannot be passed by value ("Interface not initialized"). It is now `var`.

**bc28-w1 was not tested**: it answered 503 (nginx) during the whole session.

## Live checks - bc28-is, tasks API `origo/bifrost/v1.0`, serial

| Type | Scenario | Result |
|---|---|---|
| Help.Implementation.Get | subject Storage.File.Get | Overview, Request Parameters, Response Shape, Errors, Related Message Types, plus Foundation's appended "Errors and warnings" |
| Help.MessageTypes.Get | Storage.Upload.Append, includeKeywords, lcid 1033 | keywords "send next chunk, append chunk, ..." |
| Help.MessageTypes.Get | Storage.Upload.Append, includeKeywords, lcid 1039 | keywords "senda næsta bút, bæta við bút, ..." |
| Storage.Account.List | happy path | Success |
| Storage.File.Get | nothing sent | MultipleErrors: MissingParameter storageCode, MissingParameter path |
| Storage.File.Get | unknown storageCode | RecordNotFound, parameter storageCode |
| Storage.File.Get | unknown code and `../x.txt` | MultipleErrors: RecordNotFound storageCode, InvalidParameter path |
| Storage.Upload.Append | `uploadId: "nope"`, `sequence: "abc"`, no content | MultipleErrors: InvalidParameterFormat uploadId, InvalidParameterFormat sequence, MissingParameter contentBase64 |
| Storage.Upload.Begin | buffer-only session | Success, chunkSizeHint = maxChunkBytes = 251658240 |
| Storage.Upload.Commit | no chunks | PreconditionFailed, parameter uploadId |
| Storage.Upload.Abort | cleanup of the session above | Success |
| Storage.Upload.Status | after abort | RecordNotFound, parameter uploadId |

No call returned HTTP 5xx or a call stack. Test data used the `BIFT-A` source and was cleaned up.

## Observations (not in this app)

- **Foundation response link on on-prem containers**: `tasks.data` returns
  `.../responses?tenant=default(<id>)/data` - the tenant query sits inside the path, so following the
  link fails with `Authentication_InvalidCredentials`. The working form is
  `.../responses(<id>)/data?tenant=default`.
- **bc28-is extension operations were very slow**: publishes and installs of this app ran past 10-15
  minutes and the connection dropped; the tenant reported "another service is currently modifying the
  state of extensions" for about 20 minutes. Installing through the automation API
  (`Microsoft.NAV.install`) completed. During that window the `rest` tier briefly answered
  "Unknown message type 'Storage.Account.List'"; it answered normally once the install finished.
