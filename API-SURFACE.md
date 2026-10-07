# Audit the Attachments API before publication (#77)

| Release gate | Decision at audited main |
|---|---|
| Marketplace publication / previous baseline | **BLOCKED**: Gunnar confirms no current Attachments offer; historical publication/validation and baseline evidence remain unavailable. |
| Access reduction | **HOLD**: preserve existing access until publication and consumer evidence permits a specific reduction. |
| Provider contract | **KEEP**: Storage Connector ori, Storage Type ori and table Storage Setup ori (10035636) remain public. Storage Type stays extensible. |
| State enums | **HOLD**: Storage Attachment Target ori (10035635) and Storage Upload Status ori (10035637) are candidates for Internal. |
| Registered ranges and affix | **BLOCKED**: Gunnar / Partner Center allocation owner must supply authoritative evidence for both ranges and `ori`. |
| Full AppSourceCop / product and test compile / runtime | **BLOCKED**: canonical repair PR84 (worker-3), required green checks and independently verified approved Foundation input. |
| Independent review | Pending; this audit is an author inventory, not independent certification. |

Source: Attachments main `b42ad90eaee2803205408a1cac8b0d9752b91c0e`, app `28.0.0.4`, test app
`28.0.0.6`. Compare Foundation `0fb78c0be538bd77c482c70eddbbef451f697cc9` and standards
`52ba4754cfd614e4a7c50af87b30149b18b313e3`. These are source versions, not deployed versions.
This change adds audit records only. No object, procedure, interface member, enum value,
wire name, access, extensibility, identity or allocation is changed.

## Check the complete source inventory

| Inventory | Contents |
|---|---|
| [api-surface-objects.json](api-surface-objects.json) | Every shipping object: kind/ID, access, extensibility, file hash, fields, enum values, bounded lexical app/test matches and decision. |
| [api-surface-procedures.csv](api-surface-procedures.csv) | Every non-local procedure/interface member: signature, declared modifier, effective access, source file/line and fixed-length types. |
| Matrix below | All shipping objects, including the already-internal helpers and interface-bound implementations. |
| `python3 tools/Test-ApiSurfaceMatrix.py` | Static guard checks namespace/kind/ID/path, file hashes, document decisions and Setup table/page provider attribution. It does not resolve lexical consumers or compile AL. |

Counts: 81 objects, 788 non-local procedures/interface members, 16
effectively public procedures/interface members. A public procedure on an Internal object
is recorded as effectively Internal. Object references are lexical references to the quoted
AL object name after removing line comments. Same-named table/page counts overlap;
strings and block comments may match. These bounded counts are not kind-resolved
consumers and do not prove typed use, accessibility, runtime execution or absence of
foreign consumers. The matrix identity is namespace + kind + ID + source path.
Trigger bodies and local procedures are implementation details and are excluded from the
non-local procedure inventory. The inventory records source facts; compilation must still
validate accessibility and binding compatibility.

## Preserve the demonstrated provider and message contracts

| Contract | Demonstrated consumer | Decision |
|---|---|---|
| Storage Type ori (10035636), `Extensible = true` | `test/src/StorageTypeTest.EnumExt.al` adds Mock and binds the mock provider. | Keep public and extensible. |
| Storage Connector ori interface | Production `Storage Ext File Impl ori` and test `Storage Mock Impl` implement its 11 members. | Preserve all names, parameter types, order and return types. Do not add or remove members. |
| Table Storage Setup ori (10035636) | Every provider member accepts this record; production and mock providers read its settings. | Keep public and sealed; its record type is part of the provider signature. |
| Foundation message bindings | Shipping enum extensions bind Msg Interface ori / Msg Contract ori / Msg Discovery ori to Internal implementations. | Keep bindings and every existing wire name/ordinal; internal implementations are already intentional. |
| Friend test access | `app/app.json` names only Attachments Tests; `.AL-Go/PipelineInitialize.ps1` removes it and AS0081 outside Test mode. | Preserve the seam; #78 owns compiled-package friend validation. |
| State enums 10035635 / 10035637 | Attachment management/link state and upload session/status use them; tests access the Internal implementation via the existing friend grant. | Candidate Internal only after first-publish/baseline verification; currently unchanged and sealed. |
| Existing UI pages / native fields / permissions | Setup registration, TestPage tests, native attachment integration and permission extensions. | Preserve working entry points and fields; keep already sealed pages/tables sealed. |

The provider interface accepts unbounded `Text` paths. Its setup record carries `Code[20]`,
`Description: Text[100]`, `File Account Name: Text[250]` and `Base Path: Text[250]`.
Those fields are public schema obligations even though they are not fixed-length procedure
parameters. Do not widen fields or change `var` parameter lengths on a published baseline
without compatibility analysis. No effectively public procedure currently takes fixed-length
`Code` or `Text`; fixed-length parameters on Internal helpers are listed in the CSV.

The other five public procedures are `Storage Account Lookup ori.SetConnector` /
`GetSelectedAccount` and page `Storage Setup ori` (10035637): `ClearFileAccount` / `HasFileAccount` /
`TestConnection`. Their demonstrated callers are local UI/setup code and tests, rather than
provider interface requirements. They are additional candidates for Internal after the same
publication and consumer gates clear. Preserve their current signatures until then; do not
internalize the Setup record needed by the provider.

No shipping object declares an IntegrationEvent, BusinessEvent or InternalEvent publisher.
Subscriber procedures and interface bindings are retained; zero lexical object references
does not make an event subscriber unused.

### Preserve these public signatures

| Object | Signature | Fixed-length parameter types |
|---|---|---|
| Storage Account Lookup ori | `SetConnector(Connector: Enum "Ext. File Storage Connector")` | None |
| Storage Account Lookup ori | `GetSelectedAccount(var TempFileAccount: Record "File Account" temporary)` | None |
| Storage Setup ori | `ClearFileAccount()` | None |
| Storage Setup ori | `HasFileAccount(): Boolean` | None |
| Storage Setup ori | `TestConnection()` | None |
| Storage Connector ori | `TestConnection(StorageSetup: Record "Storage Setup ori")` | None |
| Storage Connector ori | `ListEntries(StorageSetup: Record "Storage Setup ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"; var TempFileAccountContent: Record "File Account Content" temporary)` | None |
| Storage Connector ori | `GetFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")` | None |
| Storage Connector ori | `CreateFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")` | None |
| Storage Connector ori | `DeleteFile(StorageSetup: Record "Storage Setup ori"; Path: Text)` | None |
| Storage Connector ori | `FileExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean` | None |
| Storage Connector ori | `CopyFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)` | None |
| Storage Connector ori | `MoveFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)` | None |
| Storage Connector ori | `CreateDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)` | None |
| Storage Connector ori | `DeleteDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)` | None |
| Storage Connector ori | `DirectoryExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean` | None |

## Decide each object separately

| Object / source | Current access | Extensible | Bounded lexical matches | Decision |
|---|---|---|---|---|
| codeunit 10035668 [Storage Attach Key Subscr ori](app/src/Attachments/StorageAttachKeySubscr.Codeunit.al) | Internal | not declared / not applicable | 2 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| table 10035635 [Storage Attachment Link ori](app/src/Attachments/StorageAttachmentLink.Table.al) | Internal | false | 13 app / 5 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035635 [Storage Attachment Mgt ori](app/src/Attachments/StorageAttachmentMgt.Codeunit.al) | Internal | not declared / not applicable | 9 app / 1 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035636 [Storage Attachment Subscr ori](app/src/Attachments/StorageAttachmentSubscr.Codeunit.al) | Internal | not declared / not applicable | 2 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enum 10035635 [Storage Attachment Target ori](app/src/Attachments/StorageAttachmentTarget.Enum.al) | Public (default) | false | 1 app / 0 test files | HOLD: candidate Internal after publication/baseline and consumer gates |
| tableextension 10035636 [Storage Doc. Attach. ori](app/src/Attachments/StorageDocAttach.TableExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| tableextension 10035635 [Storage Inc. Doc. Attach. ori](app/src/Attachments/StorageIncDocAttach.TableExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013520 [Data Exchange Query ori](app/src/DataExchange/DataExchangeQuery.Codeunit.al) | Internal | not declared / not applicable | 7 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035676 [Storage Takeover ori](app/src/Install/StorageTakeover.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035681 [Storage Takeover State ori](app/src/Install/StorageTakeoverState.Codeunit.al) | Internal | not declared / not applicable | 3 app / 1 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035637 [Storage Install ori](app/src/Lifecycle/StorageInstall.Codeunit.al) | Internal | not declared / not applicable | 2 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035683 [Storage Link Upgrade ori](app/src/Lifecycle/StorageLinkUpgrade.Codeunit.al) | Internal | not declared / not applicable | 3 app / 1 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035638 [Storage Overview Subscr ori](app/src/Lifecycle/StorageOverviewSubscr.Codeunit.al) | Internal | not declared / not applicable | 2 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035639 [Storage Account List Impl ori](app/src/MessageTypes/Accounts/StorageAccountListImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035641 [Storage Att. Offload Impl ori](app/src/MessageTypes/Attachments/StorageAttOffloadImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035642 [Storage Att. Restore Impl ori](app/src/MessageTypes/Attachments/StorageAttRestoreImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035640 [Storage Attach Link Impl ori](app/src/MessageTypes/Attachments/StorageAttachLinkImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035667 [Storage Attach Record Impl ori](app/src/MessageTypes/Attachments/StorageAttachRecordImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013543 [DataExch Def Delete Impl ori](app/src/MessageTypes/DataExchange/DataExchDefDeleteImpl.Codeunit.al) | Internal | not declared / not applicable | 1 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 70013514 [DataExch DefDel MsgType ori](app/src/MessageTypes/DataExchange/DataExchDefDeleteMsgType.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| enumextension 70013521 [DataExch Def Exp EnumExt ori](app/src/MessageTypes/DataExchange/DataExchDefExport.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013536 [DataExch Def Export Impl ori](app/src/MessageTypes/DataExchange/DataExchDefExportImpl.Codeunit.al) | Internal | not declared / not applicable | 1 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013523 [DataExch Def Get Impl ori](app/src/MessageTypes/DataExchange/DataExchDefGetImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013524 [DataExch Def Import Impl ori](app/src/MessageTypes/DataExchange/DataExchDefImportImpl.Codeunit.al) | Internal | not declared / not applicable | 0 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013522 [DataExch Def List Impl ori](app/src/MessageTypes/DataExchange/DataExchDefListImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013521 [DataExch Entry Del Impl ori](app/src/MessageTypes/DataExchange/DataExchEntryDeleteImpl.Codeunit.al) | Internal | not declared / not applicable | 0 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013526 [DataExch Entry Get Impl ori](app/src/MessageTypes/DataExchange/DataExchEntryGetImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013525 [DataExch Entry List Impl ori](app/src/MessageTypes/DataExchange/DataExchEntryListImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 70013519 [DataExch Export Run EnumExt ori](app/src/MessageTypes/DataExchange/DataExchExportRun.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013534 [DataExch Export Run Impl ori](app/src/MessageTypes/DataExchange/DataExchExportRunImpl.Codeunit.al) | Internal | not declared / not applicable | 1 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013521 [DataExch Help Get Impl ori](app/src/MessageTypes/DataExchange/DataExchHelpGetImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 70013511 [DataExch Import MsgType ori](app/src/MessageTypes/DataExchange/DataExchImportMsgType.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013540 [DataExch Import Run Impl ori](app/src/MessageTypes/DataExchange/DataExchImportRunImpl.Codeunit.al) | Internal | not declared / not applicable | 1 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 70013510 [DataExch Msg Type ori](app/src/MessageTypes/DataExchange/DataExchMsgType.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013524 [DataExch Type List Impl ori](app/src/MessageTypes/DataExchange/DataExchTypeListImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 70013516 [DataExch Type Set EnumExt ori](app/src/MessageTypes/DataExchange/DataExchTypeSet.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013531 [DataExch Type Set Impl ori](app/src/MessageTypes/DataExchange/DataExchTypeSetImpl.Codeunit.al) | Internal | not declared / not applicable | 1 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035644 [Storage Dir Create Impl ori](app/src/MessageTypes/Directories/StorageDirCreateImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035645 [Storage Dir Delete Impl ori](app/src/MessageTypes/Directories/StorageDirDeleteImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035646 [Storage Dir Exists Impl ori](app/src/MessageTypes/Directories/StorageDirExistsImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035647 [Storage Dir List Impl ori](app/src/MessageTypes/Directories/StorageDirListImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035648 [Storage File Copy Impl ori](app/src/MessageTypes/Files/StorageFileCopyImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035649 [Storage File Create Impl ori](app/src/MessageTypes/Files/StorageFileCreateImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035650 [Storage File Delete Impl ori](app/src/MessageTypes/Files/StorageFileDeleteImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035651 [Storage File Exists Impl ori](app/src/MessageTypes/Files/StorageFileExistsImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035652 [Storage File Get Impl ori](app/src/MessageTypes/Files/StorageFileGetImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035653 [Storage File List Impl ori](app/src/MessageTypes/Files/StorageFileListImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035654 [Storage File Move Impl ori](app/src/MessageTypes/Files/StorageFileMoveImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035655 [Storage Help Get Impl ori](app/src/MessageTypes/Help/StorageHelpGetImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013500 [Storage Contract Parts ori](app/src/MessageTypes/StorageContractParts.Codeunit.al) | Internal | not declared / not applicable | 30 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 10035635 [Storage Msg Type ori](app/src/MessageTypes/StorageMsgType.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 10035656 [Storage Upload Abort Impl ori](app/src/MessageTypes/Upload/StorageUploadAbortImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035657 [Storage Upload Append Impl ori](app/src/MessageTypes/Upload/StorageUploadAppendImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035658 [Storage Upload Begin Impl ori](app/src/MessageTypes/Upload/StorageUploadBeginImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035659 [Storage Upload Commit Impl ori](app/src/MessageTypes/Upload/StorageUploadCommitImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035669 [Storage Upload Commit Rec ori](app/src/MessageTypes/Upload/StorageUploadCommitRec.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035660 [Storage Upload Status Impl ori](app/src/MessageTypes/Upload/StorageUploadStatusImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| permissionset 10035666 [BIFROST Attach ori](app/src/Permissions/BIFROSTAttach.PermissionSet.al) | Public | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| permissionset 70013548 [BIFROST DataExch ori](app/src/Permissions/BIFROSTDataExch.PermissionSet.al) | Public | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| permissionsetextension 10035635 [Storage Full ori](app/src/Permissions/StorageFull.PermissionSetExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 10035680 [Attachments Registration ori](app/src/Setup/AttachmentsRegistration.Codeunit.al) | Internal | not declared / not applicable | 2 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| page 10035677 [Attachments Setup ori](app/src/Setup/AttachmentsSetup.Page.al) | Public (default) | false | 4 app / 2 test files | KEEP UI entry point; HOLD any member access reduction pending baseline |
| pageextension 10035635 [Setup Ext. ori](app/src/Setup/SetupExt.PageExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| page 10035635 [Storage Account Lookup ori](app/src/Setup/StorageAccountLookup.Page.al) | Public (default) | false | 3 app / 0 test files | KEEP UI entry point; HOLD any member access reduction pending baseline |
| page 10035636 [Storage Card ori](app/src/Setup/StorageCard.Page.al) | Public (default) | false | 4 app / 0 test files | KEEP UI entry point; HOLD any member access reduction pending baseline |
| page 10035678 [Storage Conn. Part ori](app/src/Setup/StorageConnPart.Page.al) | Public (default) | false | 3 app / 0 test files | KEEP UI entry point; HOLD any member access reduction pending baseline |
| page 10035637 [Storage Setup ori](app/src/Setup/StorageSetup.Page.al) | Public (default) | false | 33 app / 7 test files | KEEP UI entry point; HOLD any member access reduction pending baseline |
| table 10035636 [Storage Setup ori](app/src/Setup/StorageSetup.Table.al) | Public (default) | false | 33 app / 7 test files | KEEP Public: provider contract |
| page 10035638 [Storage Setup Wizard ori](app/src/Setup/StorageSetupWizard.Page.al) | Public (default) | false | 3 app / 0 test files | KEEP UI entry point; HOLD any member access reduction pending baseline |
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | Public (default) | not declared / not applicable | 17 app / 2 test files | KEEP Public: provider contract |
| codeunit 10035661 [Storage Ext File Impl ori](app/src/Storage/StorageExtFileImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035662 [Storage Request Mgt ori](app/src/Storage/StorageRequestMgt.Codeunit.al) | Internal | not declared / not applicable | 30 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035682 [Storage Request Reader ori](app/src/Storage/StorageRequestReader.Codeunit.al) | Internal | not declared / not applicable | 16 app / 1 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enum 10035636 [Storage Type ori](app/src/Storage/StorageType.Enum.al) | Public (default) | true | 1 app / 1 test files | KEEP Public: provider contract |
| codeunit 10035663 [Storage Data Restriction ori](app/src/Upload/StorageDataRestriction.Codeunit.al) | Internal | not declared / not applicable | 2 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035664 [Storage Reten. Policy ori](app/src/Upload/StorageRetenPolicy.Codeunit.al) | Internal | not declared / not applicable | 2 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| table 10035637 [Storage Upload Chunk ori](app/src/Upload/StorageUploadChunk.Table.al) | Internal | false | 6 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035665 [Storage Upload Mgt ori](app/src/Upload/StorageUploadMgt.Codeunit.al) | Internal | not declared / not applicable | 8 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035679 [Storage Upload Purge ori](app/src/Upload/StorageUploadPurge.Codeunit.al) | Internal | not declared / not applicable | 3 app / 1 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| table 10035638 [Storage Upload Session ori](app/src/Upload/StorageUploadSession.Table.al) | Internal | false | 6 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enum 10035637 [Storage Upload Status ori](app/src/Upload/StorageUploadStatus.Enum.al) | Public (default) | false | 2 app / 0 test files | HOLD: candidate Internal after publication/baseline and consumer gates |

## Bound the consumer search

| Search corpus | Result |
|---|---|
| Attachments app and test at audited main | Bounded lexical matches are recorded per object in the JSON; table/page subtype attribution requires typed evidence. The mock provider, setup tests and message conformance tests are demonstrated seams. |
| Foundation at comparison SHA | No quoted shipping Attachments object references found. |
| Current feature/reference main snapshots | No quoted shipping Attachments object references, Attachments namespace references, app-ID dependencies or Bifrost Attachments manifest dependencies found in the scanned AL/manifests. |
| Tenant PTEs, third-party providers and Marketplace consumers | Not available. Absence cannot be inferred from the repository scan. |

The feature/reference corpus covers Timesheets, Subscription Billing, Language Models,
Orchestrator, Inventory, Warehouse, Service Management, Manufacturing, the public reference
app, Iceland, Iceland Treasury and Iceland DocEx. Exact snapshot SHAs and full search outputs
are retained in worker-4 task evidence. This is a bounded search of those sources, not proof
that no foreign consumer exists. Preserve any consumer demonstrated before a reduction.

## Obtain publication and allocation evidence

| Required evidence | Current evidence / limitation | Owner / next action |
|---|---|---|
| Marketplace first-publish status for AppId `672df32a-a0c5-4a22-b591-0efa38023e95` | Gunnar confirms no current Attachments Partner Center offer (saved operator decision). Historical validation/publication and any baseline remain unverified; empty GitHub releases and absent AppSourceCop.version do not prove first publication. | Gunnar / designated evidence owner: provide historical AppId publication/validation determination or actual baseline version/package/hash; no existing offer ID is requested. |
| Existing tenant/foreign consumer disposition | Source search above is bounded; tenant extensions and unknown provider apps are not visible. | Gunnar / product owner: identify existing consumer obligations before accepting access reduction. |
| `10035635–10035684` registration | `.claude/CLAUDE.md` asserts workbook allocation. The authoritative allocation workbook/registration record is unavailable. | Gunnar / allocation owner: supply registration tied to the actual app and publisher. |
| `70013500–70013549` registration | app.json declares it and shipping source uses it. Declaration is not registration evidence. | Gunnar / allocation owner: supply the same authoritative registration evidence for this second block. |
| `ori` affix / `Origo` publisher registration | AppSourceCop.json requires `ori` and publisher Origo. Compiler configuration is not registration evidence. | Gunnar / publisher registration owner: supply authoritative affix/publisher evidence. |

The standards `config/appsource-ranges.json` is a separate, historically audited catalog.
It does not establish registration for these declared blocks. Catalog absence is **not** a
finding that an allocation is missing. No ID, publisher or AppId is reassigned by inference.
The published legacy Origo Cloud Events Storage app has a different AppId and allocation;
its publication does not establish this app's publication state.

## Resume the held checks

1. Internal-review confirms the per-object decisions and evidence boundaries on the draft PR.
2. Obtain authoritative first-publish/baseline, foreign-consumer and both-range/affix evidence.
   Preserve published obligations if a baseline exists. Run AppSourceCop against that exact
   baseline package; an automatic “initial” phase inferred from absent configuration is not proof.
3. After the publication/consumer gate clears, implement only justified per-object reductions.
   Preserve Storage Type extensibility, all 11 provider members, the Setup record, Foundation
   bindings, native fields, wire values and the existing Test-mode seam.
4. After actual canonical [PR84](https://github.com/businesscentralal/bc-origo-bifrost-attachments/pull/84) (worker-3) merge and independently verified approved Foundation input, compile
   product and tests with full AppSourceCop and zero errors/warnings; record compiler/package
   identities. Run provider/message conformance regressions on an owned disposable COSMO
   environment, MCP and UI checks as applicable, and verify environment deletion.
5. Re-run all guards and gateway Layer 1 then Layer 2 at the final SHA. #78 owns analyzer/
   compiled-package enforcement. Keep release checklist #83 open until evidence is complete.

PR86 at `0e45a9c5771463fa4a08359a8c71e7598513c65f` failed Default, Test and
Pull Request Status Check in [run 37518573084](https://github.com/businesscentralal/bc-origo-bifrost-attachments/actions/runs/37518573084).
The resolved shared-compile decision assigns the 16 product errors (AL0185, AL0264,
AL0231) and AL0659 warning to worker-3 / PR84. These are required failures, with no
baseline-red waiver. PR87 is donor-only on explicit hold; PR91 has a separate pipeline
owner. Analyzer/QA worker-8 and tooling worker-6 retain their assignments; this audit
creates no third compile repair. New-tip checks must be observed through the exact-SHA
CI watch, not inferred from historical runs or polled by a model.

The current approved Foundation input is main `336b91d9fff11b71ae5cd75dee08186d4218bf07`,
run `37544940349` attempt 2, signed `Origo_Bifrost Foundation_28.0.2.523.app`,
SHA256 `5901BEBE66B44E91ED6110620E62EE45D122BA9E0378DCFDA4AEEF4D00D3AE0F`,
with zero friends. Independently verify exact bytes, manifest and provenance before
compilation. Historical 517/518 inputs are not current acceptance evidence. The declared
Foundation floor remains `28.0.1.0`.

The resolved publication-registration-plan permits this bounded audit correction only.
Source preparation does not release publication, runtime, QA, infrastructure or physical-writer
holds. No product/test compilation, deployed app, baseline comparison, runtime pass count or
Marketplace certification is claimed here; no COSMO environment was created for the audit.
All technical decisions stay in internal-review. No Slack handoff, offer creation, publication
or merge is authorized by this checklist.
