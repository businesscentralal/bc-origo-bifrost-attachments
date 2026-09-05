# User Scenarios — Bifröst Hnitbjörg

**Publisher:** Origo
**App:** Bifrost Hnitbjorg (`672df32a-a0c5-4a22-b591-0efa38023e95`)
**Version:** 28.0.0.0
**Submission Date:** 2026-09-05
**Test Environment:** Requires a configured Azure Blob Storage account or SharePoint document library accessible from the BC sandbox. See "Test Credentials" section below.

---

## Test Credentials

This extension connects to external cloud storage via the standard Business Central
External File Storage connectors (Azure Blob Storage, Azure File Share, SharePoint).

**Option:** Provide a test Azure Blob Storage account with a container pre-created.
Include the storage account name, container name, and a SAS token or access key
valid for at least 4 weeks from submission date.

The extension itself does not store secrets — it delegates to the BC connector apps
(e.g., "Azure Blob Storage Connector" from Microsoft). The validator must install the
appropriate connector app and configure it before testing.

---

## Scenario 1: Extension Installation and Setup

**Area:** Installation & Activation

### Setup
1. Start with a clean BC sandbox (Cronus company)
2. Install the "Bifrost Foundation" extension (dependency)
3. Install the "Bifrost Hnitbjorg" extension

### Steps
1. Search for "Bifrost Storage Setup" in the BC search bar
2. Verify the list page opens without error
3. Choose "New" to create a new storage connection
4. Enter "TEST" in the "Code" field
5. Enter "Test Storage Connection" in the "Description" field
6. Set the "Connector" field to the installed connector (e.g., "Azure Blob Storage")
7. Choose the "Select File Account" action and pick the configured file account
8. Set "Enabled" to true
9. Choose "Test Connection" and confirm the success message
10. Close the card page

### Expected Results
- The "Bifrost Storage Setup" page opens and is editable
- A new storage connection record is saved with Code = "TEST"
- The connection appears in the list page
- "Test Connection" reports that the connection is reachable

### Notes
- The "Connector" dropdown shows only connectors from installed BC connector apps
- The "Select File Account" lookup shows accounts registered by the selected connector
- "Base Path" may be left blank to address the account root

---

## Scenario 2: List Storage Accounts via Bifrost API

**Area:** Core Functionality

### Setup
1. Complete Scenario 1 (storage connection "TEST" exists)
2. Open a REST client (Postman or equivalent) configured for OData access to the BC sandbox

### Steps
1. POST a new record to the Bifrost Queue API page:
   - `type`: `Storage.Account.List`
   - `sendContent`: `{}` (empty JSON)
2. POST to the Bifrost Task API to process the message
3. GET the processed message from the Bifrost Data API
4. Verify the response JSON contains the configured storage account

### Expected Results
- The queue accepts the message without error
- The task processes successfully (status changes to completed)
- The response JSON contains an array with at least one entry showing `"code": "TEST"` and the connector type
- No secrets (keys, tokens) are included in the response

---

## Scenario 3: List Files in a Directory

**Area:** Core Functionality

### Setup
1. Complete Scenario 1 (storage connection "TEST" exists)
2. Ensure the connected storage account contains at least 2 files in the root or a known directory

### Steps
1. POST a new record to the Bifrost Queue API page:
   - `type`: `Storage.File.List`
   - `sendContent`: `{"storageCode": "TEST", "path": ""}`
2. POST to the Bifrost Task API to process the message
3. GET the processed message from the Bifrost Data API

### Expected Results
- The task processes successfully
- The response JSON contains an array of file entries with name, path, and size information
- At least 2 files are listed (matching the pre-existing files in storage)

---

## Scenario 4: Upload and Download a File

**Area:** Core Functionality

### Setup
1. Complete Scenario 1 (storage connection "TEST" exists)
2. Prepare a small test file content encoded as base64 (e.g., "Hello World" = `SGVsbG8gV29ybGQ=`)

### Steps
1. POST a new record to the Bifrost Queue API page:
   - `type`: `Storage.File.Create`
   - `sendContent`: `{"storageCode": "TEST", "path": "test-upload.txt", "contentBase64": "SGVsbG8gV29ybGQ="}`
2. POST to the Bifrost Task API to process the message
3. Verify the task completes successfully
4. POST a new record to the Bifrost Queue API page:
   - `type`: `Storage.File.Get`
   - `sendContent`: `{"storageCode": "TEST", "path": "test-upload.txt"}`
5. POST to the Bifrost Task API to process the message
6. GET the processed message from the Bifrost Data API

### Expected Results
- Step 3: The file creation task completes without error
- Step 6: The response contains the file content as base64, matching the uploaded content (`SGVsbG8gV29ybGQ=`)

---

## Scenario 5: Check File Existence

**Area:** Core Functionality

### Setup
1. Complete Scenario 4 (file "test-upload.txt" exists in storage)

### Steps
1. POST a new record to the Bifrost Queue API page:
   - `type`: `Storage.File.Exists`
   - `sendContent`: `{"storageCode": "TEST", "path": "test-upload.txt"}`
2. POST to the Bifrost Task API to process the message
3. GET the response from the Bifrost Data API
4. POST another message:
   - `type`: `Storage.File.Exists`
   - `sendContent`: `{"storageCode": "TEST", "path": "nonexistent-file.txt"}`
5. Process and retrieve the response

### Expected Results
- Step 3: Response indicates the file exists (`"exists": true`)
- Step 5: Response indicates the file does not exist (`"exists": false`)

---

## Scenario 6: Copy and Move a File

**Area:** Core Functionality

### Setup
1. Complete Scenario 4 (file "test-upload.txt" exists in storage)

### Steps
1. POST a Bifrost message:
   - `type`: `Storage.File.Copy`
   - `sendContent`: `{"storageCode": "TEST", "sourcePath": "test-upload.txt", "targetPath": "test-copy.txt"}`
2. Process the task and verify completion
3. POST a Bifrost message:
   - `type`: `Storage.File.Exists`
   - `sendContent`: `{"storageCode": "TEST", "path": "test-copy.txt"}`
4. Process and verify the copy exists
5. POST a Bifrost message:
   - `type`: `Storage.File.Move`
   - `sendContent`: `{"storageCode": "TEST", "sourcePath": "test-copy.txt", "targetPath": "test-moved.txt"}`
6. Process and verify completion
7. Verify "test-copy.txt" no longer exists and "test-moved.txt" does exist

### Expected Results
- Step 2: Copy completes without error
- Step 4: The copied file exists
- Step 6: Move completes without error
- Step 7: Original path is gone, new path exists

---

## Scenario 7: Directory Operations

**Area:** Core Functionality

### Setup
1. Complete Scenario 1 (storage connection "TEST" exists)

### Steps
1. POST a Bifrost message:
   - `type`: `Storage.Directory.Create`
   - `sendContent`: `{"storageCode": "TEST", "path": "test-dir"}`
2. Process the task
3. POST a Bifrost message:
   - `type`: `Storage.Directory.Exists`
   - `sendContent`: `{"storageCode": "TEST", "path": "test-dir"}`
4. Process and retrieve the response
5. POST a Bifrost message:
   - `type`: `Storage.Directory.List`
   - `sendContent`: `{"storageCode": "TEST", "path": ""}`
6. Process and retrieve the response
7. POST a Bifrost message:
   - `type`: `Storage.Directory.Delete`
   - `sendContent`: `{"storageCode": "TEST", "path": "test-dir"}`
8. Process and verify completion

### Expected Results
- Step 2: Directory creation succeeds
- Step 4: Response shows `"exists": true`
- Step 6: The directory list includes "test-dir"
- Step 8: Directory deletion succeeds

---

## Scenario 8: Chunked Upload (Large File)

**Area:** Core Functionality

### Setup
1. Complete Scenario 1 (storage connection "TEST" exists)
2. Prepare two base64 chunks representing parts of a file

### Steps
1. POST a Bifrost message:
   - `type`: `Storage.Upload.Begin`
   - `sendContent`: `{"storageCode": "TEST", "fileName": "large-file.dat"}`
2. Process the task and note the returned `uploadId` and `chunkSizeHint`
3. POST a Bifrost message:
   - `type`: `Storage.Upload.Append`
   - `sendContent`: `{"uploadId": "<upload-id>", "sequence": 1, "contentBase64": "<base64-chunk-1>"}`
4. Process the task
5. POST a Bifrost message:
   - `type`: `Storage.Upload.Status`
   - `sendContent`: `{"uploadId": "<upload-id>"}`
6. Process and verify the status shows 1 chunk received
7. POST a Bifrost message:
   - `type`: `Storage.Upload.Commit`
   - `sendContent`: `{"uploadId": "<upload-id>"}`
8. Process and verify the file is written to storage

### Expected Results
- Step 2: An `uploadId` and a `chunkSizeHint` are returned in the response
- Step 4: Chunk append succeeds
- Step 6: Status shows the upload session is active with progress information
- Step 8: Commit succeeds and returns the written `path` (`bifrost-uploads/large-file.dat`); the file is accessible via `Storage.File.Exists`

---

## Scenario 9: Abort a Chunked Upload

**Area:** Error Handling

### Setup
1. Complete Scenario 1 (storage connection "TEST" exists)

### Steps
1. Begin a chunked upload session (as in Scenario 8, steps 1-2)
2. POST a Bifrost message:
   - `type`: `Storage.Upload.Abort`
   - `sendContent`: `{"uploadId": "<upload-id>"}`
3. Process the task
4. Verify the file was NOT written to storage

### Expected Results
- Step 3: Abort completes without error
- Step 4: `Storage.File.Exists` for `bifrost-uploads/large-file.dat` returns `false`

---

## Scenario 10: Error Handling — Invalid Storage Code

**Area:** Error Handling

### Setup
1. Ensure no storage connection with code "INVALID" exists

### Steps
1. POST a Bifrost message:
   - `type`: `Storage.File.List`
   - `sendContent`: `{"storageCode": "INVALID", "path": ""}`
2. Process the task
3. Retrieve the response

### Expected Results
- The task completes with an error status
- The response contains a structured error message indicating the storage code was not found
- No unhandled exception or stack trace is exposed to the caller

---

## Scenario 11: Error Handling — Invalid Path

**Area:** Error Handling

### Setup
1. Complete Scenario 1 (storage connection "TEST" exists)

### Steps
1. POST a Bifrost message:
   - `type`: `Storage.File.Get`
   - `sendContent`: `{"storageCode": "TEST", "path": "this/path/does/not/exist.txt"}`
2. Process the task
3. Retrieve the response

### Expected Results
- The task completes with an error status
- The response contains a clear error message indicating the file was not found
- The error is structured JSON, not a raw BC error dialog

---

## Scenario 12: Permission Verification — Minimal Permissions

**Area:** Permission Verification

### Setup
1. Create a test user in the BC sandbox
2. Assign only the "BIFROST Hnitbj. ori" permission set to the user (plus D365 BASIC)
3. Complete Scenario 1 as an admin user

### Steps
1. Sign in as the test user
2. POST a Bifrost message via the Queue API:
   - `type`: `Storage.File.List`
   - `sendContent`: `{"storageCode": "TEST", "path": ""}`
3. Process the task
4. Retrieve the response

### Expected Results
- The test user can submit and process Bifrost messages for storage operations
- The file list is returned successfully
- No permission errors occur for standard storage read operations

---

## Scenario 13: Permission Verification — No Permission

**Area:** Permission Verification

### Setup
1. Create a test user with only D365 BASIC (no "BIFROST Hnitbj. ori" permission set)

### Steps
1. Sign in as the test user
2. Attempt to POST a Bifrost message to the Queue API

### Expected Results
- The operation fails with a clear permission error
- No data is exposed or modified

---

## Scenario 14: Delete a File

**Area:** Core Functionality

### Setup
1. Complete Scenario 4 (file "test-upload.txt" exists)

### Steps
1. POST a Bifrost message:
   - `type`: `Storage.File.Delete`
   - `sendContent`: `{"storageCode": "TEST", "path": "test-upload.txt"}`
2. Process the task
3. Verify the file no longer exists using `Storage.File.Exists`

### Expected Results
- Step 2: Deletion completes without error
- Step 3: File existence check returns `false`

---

## Scenario 15: Extension Uninstallation

**Area:** Uninstallation

### Setup
1. Complete Scenario 1 (at least one storage connection configured)

### Steps
1. Navigate to "Extension Management" in the BC search bar
2. Find "Bifrost Hnitbjorg" in the list
3. Choose "Uninstall"
4. Confirm the uninstallation
5. Verify the extension is removed from the list
6. Search for "Bifrost Storage Setup" in the BC search bar

### Expected Results
- Step 4: Uninstallation completes without error
- Step 5: The extension no longer appears in the installed extensions list
- Step 6: The search returns no results (setup page is gone)
- Standard BC functionality continues to work normally

---

## Scenario 16: Help Documentation

**Area:** Core Functionality

### Setup
1. Complete Scenario 1 (extension installed)

### Steps
1. POST a Bifrost message:
   - `type`: `Help.Storage.Get`
   - `sendContent`: `{}`
2. Process the task
3. Retrieve the response

### Expected Results
- The response contains a Markdown-formatted help document
- The document lists all available storage message types with descriptions
- The document is readable and provides usage examples

---

## Cleanup

After all scenarios are complete:
1. Delete test files from storage: `test-upload.txt`, `test-moved.txt`, `bifrost-uploads/large-file.dat`
2. Delete test directory: `test-dir`
3. Remove the "TEST" storage connection from Bifrost Storage Setup
4. Uninstall the extension (if not already done in Scenario 15)
