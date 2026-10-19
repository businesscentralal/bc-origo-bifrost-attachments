# Audit the Attachments API before publication (#77)

| Release gate | Decision at audited main |
|---|---|
| Marketplace publication / previous baseline | **BLOCKED**: Gunnar confirms no current Attachments offer; historical publication/validation and baseline evidence remain unavailable. |
| Access reduction | **IMPLEMENTED in [PR118](https://github.com/businesscentralal/bc-origo-bifrost-attachments/pull/118)**: the two state enums and five Storage Setup / Storage Account Lookup helper procedures are Internal; the unbound Definition.Import and Entry.Delete codeunits were removed. No current offer is evidenced, but that alone does not establish historical publication or absence of foreign consumers. Baseline/consumer acceptance remains open under AC01/AC03. |
| Provider contract | **KEEP**: Storage Connector ori, Storage Type ori and table Storage Setup ori (10035636) remain public. Storage Type stays extensible. The separate optional Storage Linked Move ori capability is public after PR144; existing connectors remain valid. |
| State enums | **DONE**: Storage Attachment Target ori (10035635) and Storage Upload Status ori (10035637) are Access = Internal. |
| Registered ranges and affix | **BLOCKED**: Gunnar / Partner Center allocation owner must supply authoritative evidence for both ranges and `ori`. |
| AppSourceCop / product and test compile / runtime | **CI VERIFIED at main `304a1c24985a00fb86b5caef10ca46ffe04096b6`**: [CI39276099802](https://github.com/businesscentralal/bc-origo-bifrost-attachments/actions/runs/39276099802) succeeded (Default, Test and Deploy to Bifrost); Test executed 354 tests with 0 failed / 0 skipped. The Default package is 28.0.0.109 with empty `InternalsVisibleTo` and one dependency, Bifrost Foundation minimum 28.0.3.530. This is existing-main evidence, not baseline comparison, UI/MCP proof or AppSource certification. The earlier receipt at `b66d1f21370e7cd4c54edfc23fd4ff9a6b6d6005` ([CI38918381017](https://github.com/businesscentralal/bc-origo-bifrost-attachments/actions/runs/38918381017), 280 executed / 280 passed) is historical. |
| Independent review | Pending; this audit is an author inventory, not independent certification. |

Current source checked: Attachments main `f4d524d9bdcfe408701e222ef463b2928f395910`,
source app `28.0.0.4`, source test app `28.0.0.6`. These source versions are not deployed versions.
The JSON retains its historical audit `sourceSha`; `hashSourceSha`, `consumerSourceSha`
and `procedureLocationsSourceSha` now identify the source snapshot above. All 94 shipping
objects and 904 non-local signatures are inventoried, including their effective access,
source declaration lines, and bounded lexical app/test references. The public surface has
12 interface members: the existing 11 connector members and the optional
`Storage Linked Move ori.SupportsLinkedMove(): Boolean` introduced by merged PR144.
This additive interface is separate from `Storage Connector ori`; existing connectors remain valid.
The capability reports source preservation on failure and an unambiguous outcome; it does not
promise destination cleanup or filesystem rollback. This audit changes no AL or contract.

Current main [CI39276099802](https://github.com/businesscentralal/bc-origo-bifrost-attachments/actions/runs/39276099802)
at `304a1c2` is green: Default, Test (354 executed, 0 failed, 0 skipped) and Deploy to Bifrost.
The earlier failure in CI39240173451 is resolved on main; this audit neither changes those tests
nor transfers passes to other commits. UI, MCP and independent verification of the candidate remain
separate pending checks. Historical CI results below stay attributable to their named commits.

The original audit at main `b42ad90eaee2803205408a1cac8b0d9752b91c0e` remains
attributable to [PR86](https://github.com/businesscentralal/bc-origo-bifrost-attachments/pull/86)
and commit `ef39ae86b5729038877b2427e9a892487ce09728`. The historical Foundation
comparison is `0fb78c0be538bd77c482c70eddbbef451f697cc9`; the available standards
snapshot is `ac05e88ab51ed4c9bbfb843508fc2484afe5ec8f`, recorded as synchronized on
2026-10-03, not freshly synchronized by this audit.

This change adds audit records only. No object, procedure, interface member, enum value,
wire name, access, extensibility, identity or allocation is changed.
This reconciliation changes audit text and inventory metadata only. The access reductions already merged in PR118
are described below; this documentation change adds no further access reduction.

## Check the complete source inventory

| Inventory | Contents |
|---|---|
| [api-surface-objects.json](api-surface-objects.json) | Every shipping object: kind/ID, access, extensibility, file hash, fields, enum values, bounded lexical app/test matches and decision. |
| [api-surface-procedures.csv](api-surface-procedures.csv) | Every non-local procedure/interface member: signature, declared modifier, effective access, source file/line and fixed-length types. |
| Matrix below | All shipping objects, including the already-internal helpers and interface-bound implementations. |
| `python3 tools/Test-ApiSurfaceMatrix.py` | Static guard checks namespace/kind/ID/path, file hashes, document decisions and Setup table/page provider attribution. It does not resolve lexical consumers or compile AL. |

Counts: 94 objects, 904 non-local procedures/interface members, 12
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
| Storage Linked Move ori interface | Attachment management checks the optional capability; the native test provider exercises supported and unsupported connectors. | Keep the existing public SupportsLinkedMove(): Boolean member; no new requirement on Storage Connector implementations. |
| Table Storage Setup ori (10035636) | Every provider member accepts this record; production and mock providers read its settings. | Keep public and sealed; its record type is part of the provider signature. |
| Foundation message bindings | Shipping enum extensions bind Msg Interface ori / Msg Contract ori / Msg Discovery ori to Internal implementations. | Keep bindings and every existing wire name/ordinal; internal implementations are already intentional. |
| Friend test access | `app/app.json` names only Attachments Tests; `.AL-Go/PipelineInitialize.ps1` removes it and AS0081 outside Test mode. | Preserve the seam; #78 owns compiled-package friend validation. |
| State enums 10035635 / 10035637 | Attachment management/link state and upload session/status use them; tests access the Internal implementation via the existing friend grant. | Internal and sealed in current source after PR118; historical baseline and foreign-consumer acceptance remain unverified. |
| Existing UI pages / native fields / permissions | Setup registration, TestPage tests, native attachment integration and permission extensions. | Preserve working entry points and fields; keep already sealed pages/tables sealed. |

The provider interface accepts unbounded `Text` paths. Its setup record carries `Code[20]`,
`Description: Text[100]`, `File Account Name: Text[250]` and `Base Path: Text[250]`.
Those fields are public schema obligations even though they are not fixed-length procedure
parameters. Do not widen fields or change `var` parameter lengths on a published baseline
without compatibility analysis. No effectively public procedure currently takes fixed-length
`Code` or `Text`; fixed-length parameters on Internal helpers are listed in the CSV.

The five former public helper procedures belong to page Storage Account Lookup ori
(10035635) and table Storage Setup ori (10035636). They are now declared Internal,
leaving the 11 provider interface members plus the separate optional linked-move member
as the effectively public procedure surface.
The objects themselves remain public, and the Setup table remains the provider Record
contract. Historical publication/consumer evidence is still required to accept the already
merged access reductions. Page Storage Setup ori (10035637) declares no non-local
procedures; it is a UI entry point, not the Setup Record used in provider parameters.

No shipping object declares an IntegrationEvent, BusinessEvent or InternalEvent publisher.
Subscriber procedures and interface bindings are retained; zero lexical object references
does not make an event subscriber unused.

### Preserve these public signatures

| Object / source | Signature | Fixed-length parameter types |
|---|---|---|
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | `TestConnection(StorageSetup: Record "Storage Setup ori")` | None |
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | `ListEntries(StorageSetup: Record "Storage Setup ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"; var TempFileAccountContent: Record "File Account Content" temporary)` | None |
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | `GetFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")` | None |
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | `CreateFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")` | None |
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | `DeleteFile(StorageSetup: Record "Storage Setup ori"; Path: Text)` | None |
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | `FileExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean` | None |
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | `CopyFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)` | None |
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | `MoveFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)` | None |
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | `CreateDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)` | None |
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | `DeleteDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)` | None |
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | `DirectoryExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean` | None |
| interface — [Storage Linked Move ori](app/src/Storage/StorageLinkedMove.Interface.al) | `SupportsLinkedMove(): Boolean` | None |

## Decide each object separately

| Object / source | Current access | Extensible | Current local consumers | Decision |
|---|---|---|---|---|
| codeunit 10035668 [Storage Attach Key Subscr ori](app/src/Attachments/StorageAttachKeySubscr.Codeunit.al) | Internal | not declared / not applicable | 2 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| table 10035635 [Storage Attachment Link ori](app/src/Attachments/StorageAttachmentLink.Table.al) | Internal | false | 14 app / 12 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035635 [Storage Attachment Mgt ori](app/src/Attachments/StorageAttachmentMgt.Codeunit.al) | Internal | not declared / not applicable | 9 app / 5 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035636 [Storage Attachment Subscr ori](app/src/Attachments/StorageAttachmentSubscr.Codeunit.al) | Internal | not declared / not applicable | 2 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enum 10035635 [Storage Attachment Target ori](app/src/Attachments/StorageAttachmentTarget.Enum.al) | Internal | false | 1 app / 0 test files | KEEP Internal: current merged state; historical baseline and foreign-consumer acceptance pending |
| tableextension 10035636 [Storage Doc. Attach. ori](app/src/Attachments/StorageDocAttach.TableExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| tableextension 10035635 [Storage Inc. Doc. Attach. ori](app/src/Attachments/StorageIncDocAttach.TableExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013505 [DataExch Def Transfer ori](app/src/DataExchange/DataExchDefTransfer.Codeunit.al) | Internal | not declared / not applicable | 4 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| table 70013500 [DataExch Entry Link ori](app/src/DataExchange/DataExchEntryLink.Table.al) | Internal | false | 8 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013503 [DataExch Export Mgt ori](app/src/DataExchange/DataExchExportMgt.Codeunit.al) | Internal | not declared / not applicable | 5 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013501 [DataExch Import Mgt ori](app/src/DataExchange/DataExchImportMgt.Codeunit.al) | Internal | not declared / not applicable | 9 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013504 [DataExch Pay Capture ori](app/src/DataExchange/DataExchPayCapture.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013502 [DataExch Process Worker ori](app/src/DataExchange/DataExchProcessWorker.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013511 [DataExch View Filter ori](app/src/DataExchange/DataExchViewFilter.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013520 [Data Exchange Query ori](app/src/DataExchange/DataExchangeQuery.Codeunit.al) | Internal | not declared / not applicable | 8 app / 8 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035676 [Storage Takeover ori](app/src/Install/StorageTakeover.Codeunit.al) | Internal | not declared / not applicable | 4 app / 5 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035681 [Storage Takeover State ori](app/src/Install/StorageTakeoverState.Codeunit.al) | Internal | not declared / not applicable | 3 app / 3 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035637 [Storage Install ori](app/src/Lifecycle/StorageInstall.Codeunit.al) | Internal | not declared / not applicable | 2 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035683 [Storage Link Upgrade ori](app/src/Lifecycle/StorageLinkUpgrade.Codeunit.al) | Internal | not declared / not applicable | 3 app / 4 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035638 [Storage Overview Subscr ori](app/src/Lifecycle/StorageOverviewSubscr.Codeunit.al) | Internal | not declared / not applicable | 2 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035639 [Storage Account List Impl ori](app/src/MessageTypes/Accounts/StorageAccountListImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035641 [Storage Att. Offload Impl ori](app/src/MessageTypes/Attachments/StorageAttOffloadImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035642 [Storage Att. Restore Impl ori](app/src/MessageTypes/Attachments/StorageAttRestoreImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035640 [Storage Attach Link Impl ori](app/src/MessageTypes/Attachments/StorageAttachLinkImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035667 [Storage Attach Record Impl ori](app/src/MessageTypes/Attachments/StorageAttachRecordImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 70013514 [DataExch DefDel MsgType ori](app/src/MessageTypes/DataExchange/DataExchDefDelMsgType.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013543 [DataExch Def Delete Impl ori](app/src/MessageTypes/DataExchange/DataExchDefDeleteImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 1 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 70013521 [DataExch Def Exp EnumExt ori](app/src/MessageTypes/DataExchange/DataExchDefExpEnumExt.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013536 [DataExch Def Export Impl ori](app/src/MessageTypes/DataExchange/DataExchDefExportImpl.Codeunit.al) | Internal | not declared / not applicable | 1 app / 1 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013523 [DataExch Def Get Impl ori](app/src/MessageTypes/DataExchange/DataExchDefGetImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 8 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013509 [DataExch Def Install Impl ori](app/src/MessageTypes/DataExchange/DataExchDefInstallImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013522 [DataExch Def List Impl ori](app/src/MessageTypes/DataExchange/DataExchDefListImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 8 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013508 [DataExch Entry Delete Impl ori](app/src/MessageTypes/DataExchange/DataExchEntryDeleteImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013526 [DataExch Entry Get Impl ori](app/src/MessageTypes/DataExchange/DataExchEntryGetImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 8 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013525 [DataExch Entry List Impl ori](app/src/MessageTypes/DataExchange/DataExchEntryListImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 8 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013507 [DataExch Entry Proc Impl ori](app/src/MessageTypes/DataExchange/DataExchEntryProcImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 70013519 [DataExch Export MsgType ori](app/src/MessageTypes/DataExchange/DataExchExportMsgType.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013534 [DataExch Export Run Impl ori](app/src/MessageTypes/DataExchange/DataExchExportRunImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013521 [DataExch Help Get Impl ori](app/src/MessageTypes/DataExchange/DataExchHelpGetImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 8 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 70013511 [DataExch Import MsgType ori](app/src/MessageTypes/DataExchange/DataExchImportMsgType.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013540 [DataExch Import Run Impl ori](app/src/MessageTypes/DataExchange/DataExchImportRunImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 1 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013532 [DataExch Inc Doc Proc ori](app/src/MessageTypes/DataExchange/DataExchIncDocProc.Codeunit.al) | Internal | not declared / not applicable | 4 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 70013510 [DataExch Msg Type ori](app/src/MessageTypes/DataExchange/DataExchMsgType.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013510 [DataExch Pay Export Impl ori](app/src/MessageTypes/DataExchange/DataExchPayExportImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 70013512 [DataExch Pipeline MsgType ori](app/src/MessageTypes/DataExchange/DataExchPipelineMsgType.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013524 [DataExch Type List Impl ori](app/src/MessageTypes/DataExchange/DataExchTypeListImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 8 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 70013516 [DataExch Type Set EnumExt ori](app/src/MessageTypes/DataExchange/DataExchTypeSetEnumExt.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 70013531 [DataExch Type Set Impl ori](app/src/MessageTypes/DataExchange/DataExchTypeSetImpl.Codeunit.al) | Internal | not declared / not applicable | 2 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035644 [Storage Dir Create Impl ori](app/src/MessageTypes/Directories/StorageDirCreateImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035645 [Storage Dir Delete Impl ori](app/src/MessageTypes/Directories/StorageDirDeleteImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035646 [Storage Dir Exists Impl ori](app/src/MessageTypes/Directories/StorageDirExistsImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035647 [Storage Dir List Impl ori](app/src/MessageTypes/Directories/StorageDirListImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035648 [Storage File Copy Impl ori](app/src/MessageTypes/Files/StorageFileCopyImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035649 [Storage File Create Impl ori](app/src/MessageTypes/Files/StorageFileCreateImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035650 [Storage File Delete Impl ori](app/src/MessageTypes/Files/StorageFileDeleteImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035651 [Storage File Exists Impl ori](app/src/MessageTypes/Files/StorageFileExistsImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035652 [Storage File Get Impl ori](app/src/MessageTypes/Files/StorageFileGetImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035653 [Storage File List Impl ori](app/src/MessageTypes/Files/StorageFileListImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035654 [Storage File Move Impl ori](app/src/MessageTypes/Files/StorageFileMoveImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035655 [Storage Help Get Impl ori](app/src/MessageTypes/Help/StorageHelpGetImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013500 [Storage Contract Parts ori](app/src/MessageTypes/StorageContractParts.Codeunit.al) | Internal | not declared / not applicable | 40 app / 1 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enumextension 10035635 [Storage Msg Type ori](app/src/MessageTypes/StorageMsgType.EnumExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 10035656 [Storage Upload Abort Impl ori](app/src/MessageTypes/Upload/StorageUploadAbortImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035657 [Storage Upload Append Impl ori](app/src/MessageTypes/Upload/StorageUploadAppendImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035658 [Storage Upload Begin Impl ori](app/src/MessageTypes/Upload/StorageUploadBeginImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 70013506 [Storage Upload Commit DX ori](app/src/MessageTypes/Upload/StorageUploadCommitDX.Codeunit.al) | Internal | not declared / not applicable | 3 app / 0 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035659 [Storage Upload Commit Impl ori](app/src/MessageTypes/Upload/StorageUploadCommitImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035669 [Storage Upload Commit Rec ori](app/src/MessageTypes/Upload/StorageUploadCommitRec.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035660 [Storage Upload Status Impl ori](app/src/MessageTypes/Upload/StorageUploadStatusImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| permissionset 10035666 [BIFROST Attach ori](app/src/Permissions/BIFROSTAttach.PermissionSet.al) | Public | not declared / not applicable | 0 app / 1 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| permissionset 70013548 [BIFROST DataExch ori](app/src/Permissions/BIFROSTDataExch.PermissionSet.al) | Public | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| permissionsetextension 10035635 [Storage Full ori](app/src/Permissions/StorageFull.PermissionSetExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| codeunit 10035680 [Attachments Registration ori](app/src/Setup/AttachmentsRegistration.Codeunit.al) | Internal | not declared / not applicable | 2 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| page 10035677 [Attachments Setup ori](app/src/Setup/AttachmentsSetup.Page.al) | Public (default) | false | 4 app / 4 test files | KEEP UI entry point; HOLD any member access reduction pending baseline |
| pageextension 10035635 [Setup Ext. ori](app/src/Setup/SetupExt.PageExt.al) | Public (default) | not declared / not applicable | 0 app / 0 test files | KEEP: wire bindings, fields, setup integration or permission contract |
| page 10035635 [Storage Account Lookup ori](app/src/Setup/StorageAccountLookup.Page.al) | Public (default) | false | 3 app / 2 test files | KEEP UI entry point; HOLD any member access reduction pending baseline |
| page 10035636 [Storage Card ori](app/src/Setup/StorageCard.Page.al) | Public (default) | false | 4 app / 4 test files | KEEP UI entry point; HOLD any member access reduction pending baseline |
| page 10035678 [Storage Conn. Part ori](app/src/Setup/StorageConnPart.Page.al) | Public (default) | false | 3 app / 2 test files | KEEP UI entry point; HOLD any member access reduction pending baseline |
| page 10035637 [Storage Setup ori](app/src/Setup/StorageSetup.Page.al) | Public (default) | false | 34 app / 19 test files | KEEP UI entry point; HOLD any member access reduction pending baseline |
| table 10035636 [Storage Setup ori](app/src/Setup/StorageSetup.Table.al) | Public (default) | false | 34 app / 19 test files | KEEP Public: provider contract |
| page 10035638 [Storage Setup Wizard ori](app/src/Setup/StorageSetupWizard.Page.al) | Public (default) | false | 3 app / 2 test files | KEEP UI entry point; HOLD any member access reduction pending baseline |
| interface — [Storage Connector ori](app/src/Storage/StorageConnector.Interface.al) | Public (default) | not declared / not applicable | 17 app / 4 test files | KEEP Public: provider contract |
| codeunit 10035661 [Storage Ext File Impl ori](app/src/Storage/StorageExtFileImpl.Codeunit.al) | Internal | not declared / not applicable | 3 app / 3 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| interface — [Storage Linked Move ori](app/src/Storage/StorageLinkedMove.Interface.al) | Public (default) | not declared / not applicable | 1 app / 1 test files | KEEP Public: optional linked-move capability; existing connectors remain valid |
| codeunit 10035662 [Storage Request Mgt ori](app/src/Storage/StorageRequestMgt.Codeunit.al) | Internal | not declared / not applicable | 37 app / 6 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035682 [Storage Request Reader ori](app/src/Storage/StorageRequestReader.Codeunit.al) | Internal | not declared / not applicable | 26 app / 5 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enum 10035636 [Storage Type ori](app/src/Storage/StorageType.Enum.al) | Public (default) | true | 1 app / 2 test files | KEEP Public: provider contract |
| codeunit 10035663 [Storage Data Restriction ori](app/src/Upload/StorageDataRestriction.Codeunit.al) | Internal | not declared / not applicable | 2 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035664 [Storage Reten. Policy ori](app/src/Upload/StorageRetenPolicy.Codeunit.al) | Internal | not declared / not applicable | 2 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| table 10035637 [Storage Upload Chunk ori](app/src/Upload/StorageUploadChunk.Table.al) | Internal | false | 6 app / 6 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035665 [Storage Upload Mgt ori](app/src/Upload/StorageUploadMgt.Codeunit.al) | Internal | not declared / not applicable | 10 app / 2 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| codeunit 10035679 [Storage Upload Purge ori](app/src/Upload/StorageUploadPurge.Codeunit.al) | Internal | not declared / not applicable | 3 app / 3 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| table 10035638 [Storage Upload Session ori](app/src/Upload/StorageUploadSession.Table.al) | Internal | false | 6 app / 8 test files | KEEP Internal; preserve friend tests and Foundation interface bindings |
| enum 10035637 [Storage Upload Status ori](app/src/Upload/StorageUploadStatus.Enum.al) | Internal | false | 2 app / 0 test files | KEEP Internal: current merged state; historical baseline and foreign-consumer acceptance pending |

## Bound the consumer search

| Search corpus | Result |
|---|---|
| Attachments app and test at audited main | Bounded lexical matches are recorded per object in the JSON; table/page subtype attribution requires typed evidence. The mock provider, setup tests and message conformance tests are demonstrated seams. |
| Foundation at comparison SHA | No quoted shipping Attachments object references found. |
| Historical feature/reference snapshots from the original audit | No quoted shipping Attachments object references, Attachments namespace references, app-ID dependencies or Bifrost Attachments manifest dependencies found in the scanned AL/manifests. |
| Tenant PTEs, third-party providers and Marketplace consumers | Not available. Absence cannot be inferred from the repository scan. |

The original audit feature/reference corpus covers Timesheets, Subscription Billing, Language Models,
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

## Current acceptance and next actions

| Criterion | Current disposition | Remaining acceptance |
|---|---|---|
| AC01: reviewed matrix and first-publish evidence | Current inventory contains 94 objects, 904 non-local procedures and 12 public interface members. The guard checks source identities/hashes and qualified Setup table/page attribution. Historical external consumer searches remain bounded to their recorded snapshots. | Independent review of this reconciliation; Gunnar / designated evidence owner supplies historical publication/baseline and tenant/provider consumer disposition. |
| AC02: compatible extension points and compile | Storage Type remains public/extensible, all 11 provider signatures remain, the optional linked-move interface and Setup Record/Foundation bindings/test seam are recorded. Current main CI39276099802 at `304a1c2` is green (354 tests, 0 failed, 0 skipped). | Candidate-specific compile/analyzer/full-suite/UI evidence remains separate; baseline compatibility comparison requires the actual authoritative baseline when one exists. |
| AC03: safe access reductions or specific hold | PR118 already internalized the two state enums and five helper procedures. This audit records their source state and does not repeat those changes. | Gunnar / product owner confirms the historical baseline and foreign-consumer disposition. No further reduction is justified by absence of a current offer alone; the additive PR144 capability is recorded without claiming historical-baseline compatibility. |
| AC04: both ranges and affix registration | Source declarations are retained unchanged in the release checklist. | Gunnar / allocation and publisher registration owners provide authoritative registration evidence for 10035635–10035684, 70013500–70013549 and ori/Origo. |

The retained developer owns this bounded audit reconciliation. Ordinary technical work has
no internal-review gate. Claude Code independently verifies a published candidate; Grok PR
Reviewer owns current-tip clearance; Architect owns merge and deployment; Bifröst Tester
owns post-deployment UAT. None of these roles supplies missing human publication/allocation
evidence by inference. No offer creation or AppSource publication is authorized here.

Before any new review push or PR, retain exact-candidate product/test compilation with zero
errors/warnings, the meaningful full suite with zero failures/skips, owned Web Client checks
and self-seeded MCP for any touched message types (or a scoped no-touched-type reason).
Compiled verification-only publication is separate from PR readiness. Preserve the actual
owned development container until Tester post-deployment UAT passes and the issue closes,
then verify owned cleanup; do not delete UAT test data or foreign resources.

## Historical repair evidence

The following failed-run and diagnostic-input notes describe the original audit. They are
not current blockers: PR84, PR86, PR99, PR101, PR105, PR117 and PR118 have merged; the
current main run cited above succeeds. Their historical source and verification records
remain attributable to their original commits.

PR86 at `0e45a9c5771463fa4a08359a8c71e7598513c65f` failed Default, Test and
Pull Request Status Check in [run 37518573084](https://github.com/businesscentralal/bc-origo-bifrost-attachments/actions/runs/37518573084).
The resolved shared-compile decision assigns the 16 product errors (AL0185, AL0264,
AL0231) and AL0659 warning to worker-3 / PR84. These are required failures, with no
baseline-red waiver. PR87 is donor-only on explicit hold; PR91 has a separate pipeline
owner. Analyzer/QA worker-8 and tooling worker-6 retain their assignments; this audit
creates no third compile repair. New-tip checks must be observed through the exact-SHA
CI watch, not inferred from historical runs or polled by a model.

The historical controlled BC28 diagnostic Foundation input was main `336b91d9fff11b71ae5cd75dee08186d4218bf07`,
run `37544940349` attempt 2, signed `Origo_Bifrost Foundation_28.0.2.523.app`,
SHA256 `5901BEBE66B44E91ED6110620E62EE45D122BA9E0378DCFDA4AEEF4D00D3AE0F`,
with zero friends. Independently verify exact bytes, manifest and provenance before
diagnostic compilation. Current shipping acceptance requires the actual BC29 runner
compiler/analyzers and Foundation `28.0.3.530` source/package/hash/signature/friend
provenance under #78, with matching test libraries. The controlled 523 input and older
517/518 inputs are not current runner acceptance evidence. The declared
Foundation minimum is now `28.0.3.530` in `app/app.json` and `test/app.json`.

The resolved publication-registration-plan permits this bounded audit correction only.
Source preparation does not release publication, runtime, QA, infrastructure or physical-writer
holds. No product/test compilation, deployed app, baseline comparison, runtime pass count or
Marketplace certification is claimed here; no COSMO environment was created for the audit.
Those historical internal-review/no-Slack restrictions are superseded by the current
operating agreement. No offer creation, AppSource publication or developer merge is
authorized by this checklist.

## Postmerge refresh checkpoint

Gunnar merged PR86 at `1b42c60c4a9fc95d2c66bd4b1cfcca0bfc821893` from integration head
`eccc11337917bea8ffafeaff2fa57220f46502a3`. The inherited matrix still names pre-repair
paths and hashes; its guard previously crashed on a renamed file. This refresh records current main
identities, hashes, bounded local consumer matches and procedure locations. Historical
failed CI above remains history, not current-tip evidence. No access/extensibility,
interface, wire, identity, ID, AL source, manifest or workflow edits are proposed.
Publication, consumer, registration, runtime/QA and infrastructure holds remain explicit.

The refreshed guard reports missing/renamed object or provider paths as findings instead
of exceptions. Run `python3 -m unittest discover -s tools/tests -p test_api_surface_matrix.py -v`
for completeness, identity, duplicate, source hash, document decision and provider rejection
regressions. These are static audit tests, not Business Central runtime evidence.
