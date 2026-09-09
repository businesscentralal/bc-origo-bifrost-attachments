# Bifrost Attachments - Message Type Test Report (2026-09-05)

Full end-to-end test of every message type of **Bifrost Attachments 28.0.0.0** deployed to the COSMO Alpaca container `bc28-is` (BC 28, company CRONUS IS, user GUNNAR / SUPER), alongside the published legacy *Origo Cloud Events Storage* app.

## Method

- Every call was executed with the `origo-bc-bc28-is` MCP server's `invoke_message_type` tool (Bifrost Foundation route `origo/bifrost/v1.0`), one call at a time.
- Test data used the `BIFT-S` prefix in CRONUS IS company; existing master data and the migrated legacy attachment/setup rows were not deleted.
- For each type at least one happy-path scenario (effect verified by reading the response, and where applicable by reading BC data back) and one negative scenario (invalid input must produce a clean `status = Error`, never an unhandled exception or HTTP 5xx) were run.
- The data take-over (`Storage Takeover ori`) was verified separately by comparing the legacy `CE Storage Attachment Link` (10075985, 7 rows) and `Cloud Events Storage Setup` (10075986, 1 row) tables against the new `Storage Attachment Link ori` / `Storage Setup ori` tables: all 7 attachment links and the 1 setup row matched field-for-field (RecordSystemId, StoragePath, FileName, ContentSize, OffloadedAt, Code, Connector, FileAccountId). Only SystemCreatedAt/SystemModifiedAt differ, because DataTransfer does not carry system audit fields - expected, not a defect.
- Verdicts: **Pass** = all scenarios behaved as specified; **Fail** = at least one scenario returned a wrong result, an unhandled error or an HTTP 5xx; **Blocked** = the environment prevented the scenario (reason given).

## Summary

| Metric | Value |
|---|---|
| Message types in app | 23 |
| Message types exercised | 23 |
| Scenarios executed | 44 |
| Scenarios passed | 44 |
| Scenarios failed | 0 |
| Scenarios blocked | 0 |

### By namespace

| Namespace | Types | Pass | Fail | Blocked | Not run | Scenarios |
|---|---|---|---|---|---|---|
| Help | 1 | 1 | 0 | 0 | 0 | 1 |
| Storage | 22 | 22 | 0 | 0 | 0 | 43 |

## Defects and observations

None found. Every negative scenario returned a clean `status = Error` with a helpful message; no unhandled exception or HTTP 5xx was observed. The data take-over reproduced the legacy app's data exactly (see Method).

## Results per message type

### `Help.Storage.Get` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - overview markdown | Pass | `{}` | Success; returned full markdown overview, version 28.0.11.0 |  |

### `Storage.Account.List` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - list configured connections | Pass | `{}` | Success; 1 account TEST / Blob Storage / enabled |  |

### `Storage.File.Exists` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - existing legacy blob | Pass | `{storageCode:TEST,path:verification-test/hello.txt}` | Success; exists=true | Confirms legacy blob still reachable through new connector |
| negative - unknown storageCode | Pass | `{storageCode:BIFT-S-BOGUS,path:whatever.txt}` | Error: No storage connection is configured for storageCode 'BIFT-S-BOGUS'. | Clean status=Error, not 5xx |

### `Storage.File.Get` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - download legacy blob | Pass | `{storageCode:TEST,path:verification-test/hello.txt}` | Success; contentLength=89, base64 decodes to original legacy verification text |  |
| negative - missing file | Pass | `{storageCode:TEST,path:BIFT-S/does-not-exist.txt}` | Error: 404 The specified blob does not exist. | Real Azure Blob 404 surfaced as clean status=Error |

### `Storage.File.Create` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - upload small file | Pass | `{storageCode:TEST,path:BIFT-S/hello.txt,contentBase64:...}` | Success; contentLength=30 |  |
| negative - missing contentBase64 | Pass | `{storageCode:TEST,path:BIFT-S/missing-content.txt}` | Error: Missing required 'contentBase64' in the request. |  |

### `Storage.File.Delete` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - delete file | Pass | `{storageCode:TEST,path:BIFT-S/hello-moved.txt}` | Success |  |
| negative - missing file | Pass | `{storageCode:TEST,path:BIFT-S/already-gone.txt}` | Error: 404 The specified blob does not exist. |  |

### `Storage.File.Copy` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - copy file | Pass | `{storageCode:TEST,sourcePath:BIFT-S/hello.txt,targetPath:BIFT-S/hello-copy.txt}` | Success |  |
| negative - missing source | Pass | `{storageCode:TEST,sourcePath:BIFT-S/does-not-exist.txt,targetPath:BIFT-S/copy2.txt}` | Error: 404 The specified blob does not exist. |  |

### `Storage.File.Move` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - move file | Pass | `{storageCode:TEST,sourcePath:BIFT-S/hello-copy.txt,targetPath:BIFT-S/hello-moved.txt}` | Success |  |
| negative - missing source | Pass | `{storageCode:TEST,sourcePath:BIFT-S/does-not-exist.txt,targetPath:BIFT-S/nope.txt}` | Error: 404 The specified blob does not exist. |  |

### `Storage.File.List` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - list directory | Pass | `{storageCode:TEST,path:BIFT-S}` | Success; entries hello.txt, hello-moved.txt |  |
| negative - unknown storageCode | Pass | `{storageCode:BIFT-S-BOGUS,path:x}` | Error: No storage connection is configured for storageCode 'BIFT-S-BOGUS'. |  |

### `Storage.Directory.Exists` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - existing dir | Pass | `{storageCode:TEST,path:BIFT-S}` | Success; exists=true |  |
| negative - nonexistent dir | Pass | `{storageCode:TEST,path:BIFT-S/never-created}` | Success; exists=false | Correct false-result rather than error, per contract |

### `Storage.Directory.Create` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - create dir | Pass | `{storageCode:TEST,path:BIFT-S/subdir}` | Success |  |
| negative - unknown storageCode | Pass | `{storageCode:BIFT-S-BOGUS,path:x}` | Error: No storage connection is configured for storageCode 'BIFT-S-BOGUS'. |  |

### `Storage.Directory.Delete` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - delete dir | Pass | `{storageCode:TEST,path:BIFT-S/subdir}` | Success |  |
| negative - nonexistent dir | Pass | `{storageCode:TEST,path:BIFT-S/never-created}` | Error: 404 The specified blob does not exist. |  |

### `Storage.Directory.List` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - list subdirectories | Pass | `{storageCode:TEST,path:BIFT-S}` | Success; entries subdir |  |
| negative - unknown storageCode | Pass | `{storageCode:BIFT-S-BOGUS,path:x}` | Error: No storage connection is configured for storageCode 'BIFT-S-BOGUS'. |  |

### `Storage.Attachment.Offload` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - offload the created attachment | Pass | `{target:DocumentAttachment,systemId:55F3D242-...,storageCode:TEST,folderPath:BIFT-S}` | Success; path=BIFT-S/BIFT-S-attachment.txt |  |
| negative - unknown systemId | Pass | `{target:DocumentAttachment,systemId:00000000-0000-0000-0000-000000000000,storageCode:TEST}` | Error: No attachment record was found for the supplied SystemId. |  |

### `Storage.Attachment.Restore` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - restore the offloaded attachment | Pass | `{target:DocumentAttachment,systemId:55F3D242-...}` | Success; contentLength=31 |  |
| negative - already restored (not offloaded) | Pass | `{target:DocumentAttachment,systemId:55F3D242-...}` | Error: The attachment is not offloaded. |  |

### `Storage.Attachment.CreateLinked` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - link uploaded file to new incoming document | Pass | `{storageCode:TEST,path:BIFT-S/linked.txt,fileName:BIFT-S-linked.txt}` | Success; incomingDocumentEntryNo=878 |  |
| negative - duplicate path already linked | Pass | `{storageCode:TEST,path:BIFT-S/linked.txt,fileName:BIFT-S-linked-dup.txt}` | Error: The storage path ... is already linked to another attachment. |  |

### `Storage.Attachment.CreateForRecord` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - inline base64 on Customer 10000 | Pass | `{tableName:Customer,no:10000,content:...,fileName:BIFT-S-attachment.txt}` | Success; attachmentId=145 systemId=55F3D242-5CA9-F111-B7A5-A876EB1DF8A8 |  |
| negative - unknown record | Pass | `{tableName:Customer,no:BIFT-S-NOPE,content:...,fileName:x.txt}` | Error: No record was found in table 18 for the supplied key. |  |

### `Storage.Upload.Begin` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - open session with storageCode | Pass | `{storageCode:TEST,fileName:BIFT-S-upload.txt,declaredSize:20}` | Success; uploadId returned, path=bifrost-uploads/BIFT-S-upload.txt | declaredSize deliberately wrong (20 vs actual 29) to set up a Commit negative case |
| negative - missing fileName | Pass | `{storageCode:TEST}` | Error: Missing required 'fileName' in the request. |  |

### `Storage.Upload.Append` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - append chunk 1 | Pass | `{uploadId:F7C4EFF3-...,sequence:1,contentBase64:...}` | Success; received=29 chunkCount=1 |  |
| negative - unknown uploadId | Pass | `{uploadId:00000000-0000-0000-0000-000000000000,sequence:1,contentBase64:QQ==}` | Error: No upload session was found for the supplied uploadId. |  |

### `Storage.Upload.Commit` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| negative - declared/received size mismatch | Pass | `{uploadId:F7C4EFF3-...}` | Error: The received size (29 bytes) does not match the declared size (20 bytes). |  |
| happy - assemble and write to storage | Pass | `{uploadId:A67D297A-...}` | Success; path=bifrost-uploads/BIFT-S-upload2.txt contentLength=29 | Fresh session with correct declaredSize=29 |

### `Storage.Upload.CommitToRecord` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - commit buffer session to Customer 10000 | Pass | `{uploadId:5C2E6B64-...,tableName:Customer,no:10000}` | Success; attachmentId=146 systemId=F22DFC96-5CA9-F111-B7A5-A876EB1DF8A8 |  |
| negative - unknown uploadId | Pass | `{uploadId:00000000-0000-0000-0000-000000000000,tableName:Customer,no:10000}` | Error: No upload session was found for the supplied uploadId. |  |

### `Storage.Upload.Abort` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - discard open buffer-only session | Pass | `{uploadId:5BCF495D-...}` | Success; status=Aborted |  |
| negative - unknown uploadId | Pass | `{uploadId:00000000-0000-0000-0000-000000000000}` | Error: No upload session was found for the supplied uploadId. |  |

### `Storage.Upload.Status` - Pass

| Scenario | Status | Request data | Response | Notes |
|---|---|---|---|---|
| happy - open session progress | Pass | `{uploadId:F7C4EFF3-...}` | Success; status=Open received=29 chunkCount=1 |  |
| negative - unknown uploadId | Pass | `{uploadId:00000000-0000-0000-0000-000000000000}` | Error: No upload session was found for the supplied uploadId. |  |
