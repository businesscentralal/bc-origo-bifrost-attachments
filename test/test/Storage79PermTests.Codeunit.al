namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Foundation.Attachment;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.Text;
using System.Utilities;

/// <summary>
/// Story79 supplemental AL permission regressions through shipped dispatcher and page surfaces.
/// Exact assignments contain no test-added wildcard. Mock storage and the current authenticated
/// identity are explicit limitations: these tests do not certify SaaS identities or provider access.
/// </summary>
codeunit 96218 "Storage 79 Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        StorageCodeTok: Label 'X79-STORAGE', Locked = true;
        CustomerNoTok: Label 'X79-CUSTOMER', Locked = true;
        DefinitionCodeTok: Label 'X79-DEF', Locked = true;

    [Test]
    /// <summary>Actual advertised storage role can open and change setup through its card.</summary>
    procedure Scenario_AC01_GrantedSetupCard_PersistsChange()
    var
        StorageSetup: Record "Storage Setup ori";
        StorageCard: TestPage "Storage Card ori";
    begin
        // Story79 AC01 | Time: independent of WorkDate | Risk: actual app-role union.
        Initialize();
        LowerStorageActor();
        LibraryAssert.IsTrue(StorageSetup.WritePermission(), 'Granted setup actor must be able to mutate setup.');
        StorageSetup.Get(StorageCodeTok);
        StorageCard.OpenEdit();
        StorageCard.GoToRecord(StorageSetup);
        StorageCard.Description.SetValue('X79 changed through card');
        StorageCard.Close();
        Observe();
        Clear(StorageSetup);
        StorageSetup.ReadIsolation := IsolationLevel::ReadCommitted;
        StorageSetup.Get(StorageCodeTok);
        LibraryAssert.AreEqual('X79 changed through card', StorageSetup.Description, 'Read back the persisted page effect.');
    end;

    [Test]
    /// <summary>Read-only setup card refuses a field change and leaves persisted values intact.</summary>
    procedure Scenario_AC02_ReadOnlySetupCard_RefusesChange()
    var
        StorageSetup: Record "Storage Setup ori";
        StorageCard: TestPage "Storage Card ori";
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: page editability and permission union.
        Initialize();
        LowerActor('Storage79 Setup ori');
        LibraryAssert.IsTrue(StorageSetup.ReadPermission(), 'Read-only setup must remain reachable.');
        LibraryAssert.IsFalse(StorageSetup.WritePermission(), 'Actor must lack setup mutation before opening the card.');
        StorageSetup.Get(StorageCodeTok);
        StorageCard.OpenEdit();
        StorageCard.GoToRecord(StorageSetup);
        asserterror StorageCard.Description.SetValue('X79 forbidden card change');
        LibraryAssert.AreNotEqual('', GetLastErrorText(), 'Refused page edit must explain the failure.');
        Observe();
        StorageCard.Close();
        AssertSetupUnchanged();
    end;

    [Test]
    /// <summary>Setup insertion is denied under the read-only role, with fresh persisted readback.</summary>
    procedure Scenario_AC02_MissingSetupInsert_LeavesNoRow()
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: actual I permission.
        Initialize();
        LowerActor('Storage79 Setup ori');
        AssertReadOnlySetup();
        StorageSetup.Init();
        StorageSetup.Code := 'X79-DENIED';
        asserterror StorageSetup.Insert(true);
        AssertPlatformPermissionError();
        Observe();
        Clear(StorageSetup);
        StorageSetup.ReadIsolation := IsolationLevel::ReadCommitted;
        LibraryAssert.IsFalse(StorageSetup.Get('X79-DENIED'), 'Denied insertion must leave no row.');
        AssertSetupUnchanged();
    end;

    [Test]
    /// <summary>Setup modification is denied without changing connection fields.</summary>
    procedure Scenario_AC02_MissingSetupModify_PreservesRow()
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: actual M permission.
        Initialize();
        LowerActor('Storage79 Setup ori');
        AssertReadOnlySetup();
        StorageSetup.Get(StorageCodeTok);
        StorageSetup.Description := 'X79 forbidden modification';
        StorageSetup.Enabled := false;
        asserterror StorageSetup.Modify(true);
        AssertPlatformPermissionError();
        Observe();
        AssertSetupUnchanged();
    end;

    [Test]
    /// <summary>Setup deletion is denied and the original row remains usable.</summary>
    procedure Scenario_AC02_MissingSetupDelete_PreservesRow()
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: actual D permission.
        Initialize();
        LowerActor('Storage79 Setup ori');
        AssertReadOnlySetup();
        StorageSetup.Get(StorageCodeTok);
        asserterror StorageSetup.Delete(true);
        AssertPlatformPermissionError();
        Observe();
        AssertSetupUnchanged();
    end;

    [Test]
    /// <summary>Actual app roles dispatch shared contract discovery without experimental execute patches.</summary>
    procedure Scenario_AC01_ActualRoles_DispatchSharedHelp()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC01 | Time: independent of WorkDate | Risk: Foundation API owns codeunit wildcard.
        Initialize();
        LowerStorageActor();
        ResponseJson := Dispatch(MessageType::"Help.Storage.Get", RequestJson);
        AssertSuccess(ResponseJson);
        RequestJson.Add('messageTypes', MessageNames('Storage.File.Create'));
        ResponseJson := Dispatch(MessageType::"Help.Implementation.Get", RequestJson);
        AssertSuccess(ResponseJson);
        AssertSetupUnchangedAsActor();
    end;

    [Test]
    /// <summary>Account discovery returns the configured storage row under the advertised roles.</summary>
    procedure Scenario_AC01_GrantedAccountList_ReturnsConfiguredRow()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DataJson: JsonObject;
        AccountJson: JsonObject;
        AccountsToken: JsonToken;
        AccountToken: JsonToken;
        Accounts: JsonArray;
        FoundStorageCode: Boolean;
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC01 | Time: independent of WorkDate | Risk: discovery is not provider account selection.
        Initialize();
        LowerStorageActor();
        ResponseJson := Dispatch(MessageType::"Storage.Account.List", RequestJson);
        AssertSuccess(ResponseJson);
        DataJson := ReadData(ResponseJson);
        LibraryAssert.IsTrue(DataJson.Get('accounts', AccountsToken), 'Account discovery returns accounts.');
        Accounts := AccountsToken.AsArray();
        foreach AccountToken in Accounts do begin
            AccountJson := AccountToken.AsObject();
            if ReadText(AccountJson, 'code') = StorageCodeTok then begin
                FoundStorageCode := true;
                LibraryAssert.AreEqual('X79 original setup', ReadText(AccountJson, 'description'), 'Configured account description.');
                LibraryAssert.AreEqual('X79-root', ReadText(AccountJson, 'basePath'), 'Configured account base path.');
            end;
        end;
        LibraryAssert.IsTrue(FoundStorageCode, 'The actor actually reached its seeded storage connection.');
        Observe();
        AssertSetupUnchanged();
    end;

    [Test]
    /// <summary>File create/get/copy/move/delete and directory operations use the actual app-role union.</summary>
    procedure Scenario_AC01_GrantedFilesAndDirectories_Roundtrip()
    var
        MockState: Codeunit "Storage Mock State";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC01 | Time: independent of WorkDate | Risk: mock backend only; provider proof held.
        Initialize();
        LowerStorageActor();
        RequestJson := StorageRequest('X79-dir');
        AssertSuccess(Dispatch(MessageType::"Storage.Directory.Create", RequestJson));
        AssertSuccess(Dispatch(MessageType::"Storage.Directory.Exists", RequestJson));
        RequestJson := StorageRequest('X79-dir/X79-file.txt');
        RequestJson.Add('contentBase64', Encode('X79 original bytes'));
        AssertSuccess(Dispatch(MessageType::"Storage.File.Create", RequestJson));
        RequestJson := StorageRequest('X79-dir/X79-file.txt');
        ResponseJson := Dispatch(MessageType::"Storage.File.Get", RequestJson);
        AssertSuccess(ResponseJson);
        LibraryAssert.AreEqual(Encode('X79 original bytes'), ReadText(ReadData(ResponseJson), 'contentBase64'), 'Actor reads the uploaded bytes.');
        AssertSuccess(Dispatch(MessageType::"Storage.File.Exists", RequestJson));
        RequestJson := CopyRequest('X79-dir/X79-file.txt', 'X79-dir/X79-copy.txt');
        AssertSuccess(Dispatch(MessageType::"Storage.File.Copy", RequestJson));
        RequestJson := CopyRequest('X79-dir/X79-copy.txt', 'X79-dir/X79-moved.txt');
        AssertSuccess(Dispatch(MessageType::"Storage.File.Move", RequestJson));
        RequestJson := StorageRequest('X79-dir');
        AssertSuccess(Dispatch(MessageType::"Storage.File.List", RequestJson));
        AssertSuccess(Dispatch(MessageType::"Storage.Directory.List", RequestJson));
        RequestJson := StorageRequest('X79-dir/X79-moved.txt');
        AssertSuccess(Dispatch(MessageType::"Storage.File.Delete", RequestJson));
        RequestJson := StorageRequest('X79-dir/X79-file.txt');
        AssertSuccess(Dispatch(MessageType::"Storage.File.Delete", RequestJson));
        RequestJson := StorageRequest('X79-dir');
        AssertSuccess(Dispatch(MessageType::"Storage.Directory.Delete", RequestJson));
        Observe();
        LibraryAssert.AreEqual(0, MockState.FilePaths().Count(), 'Read back deletion of every created mock file.');
        LibraryAssert.IsFalse(MockState.HasDirectory('X79-dir'), 'Read back directory deletion.');
        AssertSetupUnchanged();
    end;

    [Test]
    /// <summary>A malformed file request must fail before the mock backend or database changes.</summary>
    procedure Scenario_AC02_InvalidFileInput_PreservesState()
    var
        MockState: Codeunit "Storage Mock State";
        RequestJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: validate before connector write.
        Initialize();
        LowerStorageActor();
        RequestJson := StorageRequest('X79-invalid.txt');
        AssertStructuredError(Dispatch(MessageType::"Storage.File.Create", RequestJson), 'MissingParameter');
        Observe();
        LibraryAssert.AreEqual(0, MockState.FilePaths().Count(), 'Missing content must create no file.');
        AssertSetupUnchanged();
    end;

    [Test]
    /// <summary>Granted upload Begin/Append/Status/Commit writes exact bytes and clears persisted chunks.</summary>
    procedure Scenario_AC01_GrantedUpload_StoresBytesAndClearsChunks()
    var
        UploadSession: Record "Storage Upload Session ori";
        UploadChunk: Record "Storage Upload Chunk ori";
        MockState: Codeunit "Storage Mock State";
        UploadId: Guid;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC01 | Time: independent of WorkDate | Risk: inherent upload grants; one real session.
        Initialize();
        LowerStorageActor();
        UploadId := BeginUpload(true);
        AppendUpload(UploadId, 1, 'X79 first ');
        AppendUpload(UploadId, 2, 'second');
        ResponseJson := Dispatch(MessageType::"Storage.Upload.Status", UploadRequest(UploadId));
        AssertSuccess(ResponseJson);
        LibraryAssert.AreEqual(2, ReadInteger(ReadData(ResponseJson), 'chunkCount'), 'Status must see both actor chunks.');
        AssertSuccess(Dispatch(MessageType::"Storage.Upload.Commit", UploadRequest(UploadId)));
        Observe();
        UploadSession.ReadIsolation := IsolationLevel::ReadCommitted;
        UploadSession.Get(UploadId);
        LibraryAssert.AreEqual(UploadSession.Status::Committed, UploadSession.Status, 'Persisted session is committed.');
        UploadChunk.ReadIsolation := IsolationLevel::ReadCommitted;
        UploadChunk.SetRange("Upload Id", UploadId);
        LibraryAssert.IsTrue(UploadChunk.IsEmpty(), 'Committed chunks are cleared.');
        LibraryAssert.AreEqual(Encode('X79 first second'), MockState.GetFileContent(UploadSession."Target Path"), 'Mock readback verifies byte order.');
    end;

    [Test]
    /// <summary>An empty upload cannot commit; subsequent actual-role abort removes its chunks.</summary>
    procedure Scenario_AC02_EmptyUpload_RefusesCommitThenAborts()
    var
        UploadSession: Record "Storage Upload Session ori";
        UploadChunk: Record "Storage Upload Chunk ori";
        MockState: Codeunit "Storage Mock State";
        UploadId: Guid;
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: no empty-upload mutation.
        Initialize();
        LowerStorageActor();
        UploadId := BeginUpload(true);
        AssertStructuredError(Dispatch(MessageType::"Storage.Upload.Commit", UploadRequest(UploadId)), 'PreconditionFailed');
        Observe();
        UploadSession.ReadIsolation := IsolationLevel::ReadCommitted;
        UploadSession.Get(UploadId);
        LibraryAssert.AreEqual(UploadSession.Status::Open, UploadSession.Status, 'Denied empty commit keeps the session open.');
        LibraryAssert.AreEqual(0, MockState.FilePaths().Count(), 'Empty commit creates no file.');
        LowerStorageActor();
        AppendUpload(UploadId, 1, 'X79 abort bytes');
        AssertSuccess(Dispatch(MessageType::"Storage.Upload.Abort", UploadRequest(UploadId)));
        Observe();
        Clear(UploadSession);
        UploadSession.ReadIsolation := IsolationLevel::ReadCommitted;
        UploadSession.Get(UploadId);
        LibraryAssert.AreEqual(UploadSession.Status::Aborted, UploadSession.Status, 'Abort is persisted.');
        UploadChunk.ReadIsolation := IsolationLevel::ReadCommitted;
        UploadChunk.SetRange("Upload Id", UploadId);
        LibraryAssert.IsTrue(UploadChunk.IsEmpty(), 'Abort clears its persisted chunks.');
        LibraryAssert.AreEqual(0, MockState.FilePaths().Count(), 'Abort writes no mock file.');
    end;

    [Test]
    /// <summary>Granted CommitToRecord and CreateForRecord produce native attachments with actual persisted content.</summary>
    procedure Scenario_AC01_GrantedNativeTarget_PersistsContent()
    var
        UploadId: Guid;
        RequestJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC01 | Time: independent of WorkDate | Risk: enumerated native baseline only.
        Initialize();
        LowerNativeActor(true);
        UploadId := BeginUpload(false);
        AppendUpload(UploadId, 1, 'X79 buffered bytes');
        RequestJson := NativeRequest(UploadId);
        AssertSuccess(Dispatch(MessageType::"Storage.Upload.CommitToRecord", RequestJson));
        RequestJson := CreateAttachmentRequest();
        AssertSuccess(Dispatch(MessageType::"Storage.Attachment.CreateForRecord", RequestJson));
        Observe();
        AssertNativeAttachments(2);
        AssertAttachmentBytes('X79-upload', 'X79 buffered bytes');
        AssertAttachmentBytes('X79-inline', 'X79 inline bytes');
    end;

    [Test]
    /// <summary>Missing Customer read is denied at the genuine source table before a target attachment is inserted.</summary>
    procedure Scenario_AC02_MissingSourceRead_CreatesNothing()
    var
        Customer: Record Customer;
        DocumentAttachment: Record "Document Attachment";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: isolate source read from target mutation.
        Initialize();
        LowerStorageActor();
        LowerPermissions.AddPermissionSet('Storage79 Source ori');
        LibraryAssert.IsFalse(Customer.ReadPermission(), 'The actual actor must lack Customer read.');
        LibraryAssert.IsTrue(DocumentAttachment.WritePermission(), 'Target mutation must be granted to isolate source denial.');
        RequestJson := CreateAttachmentRequest();
        ResponseJson := Dispatch(MessageType::"Storage.Attachment.CreateForRecord", RequestJson);
        Observe();
        AssertNativeAttachments(0);
        AssertSetupUnchanged();
        AssertStructuredError(ResponseJson, 'PermissionDenied');
    end;

    [Test]
    /// <summary>Missing native mutation cannot consume a buffered session or its persisted chunk.</summary>
    procedure Scenario_AC02_MissingTargetWrite_PreservesUpload()
    var
        Customer: Record Customer;
        DocumentAttachment: Record "Document Attachment";
        UploadSession: Record "Storage Upload Session ori";
        UploadChunk: Record "Storage Upload Chunk ori";
        UploadId: Guid;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: prevent denied commit from consuming chunks.
        Initialize();
        LowerNativeActor(true);
        UploadId := BeginUpload(false);
        AppendUpload(UploadId, 1, 'X79 retained bytes');
        Observe();
        LowerNativeActor(false);
        LibraryAssert.IsTrue(Customer.ReadPermission(), 'Source table remains readable.');
        LibraryAssert.IsTrue(DocumentAttachment.ReadPermission(), 'Native target remains readable.');
        LibraryAssert.IsFalse(DocumentAttachment.WritePermission(), 'Native target mutation must actually be absent.');
        RequestJson := NativeRequest(UploadId);
        ResponseJson := Dispatch(MessageType::"Storage.Upload.CommitToRecord", RequestJson);
        Observe();
        AssertNativeAttachments(0);
        UploadSession.ReadIsolation := IsolationLevel::ReadCommitted;
        UploadSession.Get(UploadId);
        LibraryAssert.AreEqual(UploadSession.Status::Open, UploadSession.Status, 'Denied target write keeps the session open.');
        LibraryAssert.AreEqual(1, UploadSession."Chunk Count", 'Denied target write preserves chunk metadata.');
        UploadChunk.ReadIsolation := IsolationLevel::ReadCommitted;
        UploadChunk.Get(UploadId, 1);
        LibraryAssert.AreEqual(18, UploadChunk.Size, 'Denied target write preserves chunk byte size.');
        AssertChunkBytes(UploadChunk, 'X79 retained bytes');
        AssertStructuredError(ResponseJson, 'PermissionDenied');
    end;

    [Test]
    /// <summary>Granted offload, transparent open and restore preserve the native content roundtrip.</summary>
    procedure Scenario_AC01_GrantedOffloadOpenRestore_Roundtrips()
    var
        DocumentAttachment: Record "Document Attachment";
        AttachmentLink: Record "Storage Attachment Link ori";
        MockState: Codeunit "Storage Mock State";
        AttachmentId: Guid;
        StoragePath: Text;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC01 | Time: offload timestamp not asserted | Risk: #11 native contract hold remains.
        Initialize();
        SeedNativeAttachment(AttachmentId);
        LowerNativeActor(true);
        RequestJson := AttachmentRequest(AttachmentId);
        RequestJson.Add('storageCode', StorageCodeTok);
        ResponseJson := Dispatch(MessageType::"Storage.Attachment.Offload", RequestJson);
        AssertSuccess(ResponseJson);
        Observe();
        AttachmentLink.ReadIsolation := IsolationLevel::ReadCommitted;
        AttachmentLink.Get(Database::"Document Attachment", AttachmentId);
        StoragePath := AttachmentLink."Storage Path";
        LibraryAssert.AreEqual(Encode('X79 inline bytes'), MockState.GetFileContent(StoragePath), 'Offload writes exact mock bytes.');
        LowerNativeActor(true);
        DocumentAttachment.GetBySystemId(AttachmentId);
        AssertOpenAttachmentBytes(DocumentAttachment, 'X79 inline bytes');
        RequestJson := AttachmentRequest(AttachmentId);
        AssertSuccess(Dispatch(MessageType::"Storage.Attachment.Restore", RequestJson));
        Observe();
        Clear(AttachmentLink);
        AttachmentLink.ReadIsolation := IsolationLevel::ReadCommitted;
        LibraryAssert.IsFalse(AttachmentLink.Get(Database::"Document Attachment", AttachmentId), 'Restore removes the persisted link.');
        LibraryAssert.IsFalse(MockState.HasFile(StoragePath), 'Restore removes the mock remote copy.');
        Clear(DocumentAttachment);
        DocumentAttachment.ReadIsolation := IsolationLevel::ReadCommitted;
        DocumentAttachment.GetBySystemId(AttachmentId);
        AssertOpenAttachmentBytes(DocumentAttachment, 'X79 inline bytes');
    end;

    [Test]
    /// <summary>Link mutation denial occurs before clearing the native blob or writing mock storage.</summary>
    procedure Scenario_AC02_MissingLinkWrite_PreservesNativeAndStorage()
    var
        DocumentAttachment: Record "Document Attachment";
        AttachmentLink: Record "Storage Attachment Link ori";
        MockState: Codeunit "Storage Mock State";
        AttachmentId: Guid;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: app-only omission fixture.
        Initialize();
        SeedNativeAttachment(AttachmentId);
        LowerActor('Storage79 Link ori');
        AddNativeBaseline();
        LibraryAssert.IsTrue(AttachmentLink.ReadPermission(), 'Link read must remain granted.');
        LibraryAssert.IsFalse(AttachmentLink.WritePermission(), 'Link mutation must actually be absent.');
        LibraryAssert.IsTrue(DocumentAttachment.WritePermission(), 'Native write remains granted to isolate link denial.');
        RequestJson := AttachmentRequest(AttachmentId);
        RequestJson.Add('storageCode', StorageCodeTok);
        ResponseJson := Dispatch(MessageType::"Storage.Attachment.Offload", RequestJson);
        Observe();
        AttachmentLink.ReadIsolation := IsolationLevel::ReadCommitted;
        LibraryAssert.IsFalse(AttachmentLink.Get(Database::"Document Attachment", AttachmentId), 'Denied offload creates no link.');
        DocumentAttachment.ReadIsolation := IsolationLevel::ReadCommitted;
        DocumentAttachment.GetBySystemId(AttachmentId);
        AssertOpenAttachmentBytes(DocumentAttachment, 'X79 inline bytes');
        LibraryAssert.AreEqual(0, MockState.FilePaths().Count(), 'Denied offload never reaches remote mutation.');
        AssertStructuredError(ResponseJson, 'PermissionDenied');
    end;

    [Test]
    /// <summary>Actual Data Exchange discovery role can retrieve a fully seeded definition and entry.</summary>
    procedure Scenario_AC01_GrantedDataExchange_ReadsSeededGraph()
    var
        EntryNo: Integer;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC01 | Time: independent of WorkDate | Risk: shipped discovery only.
        Initialize();
        EntryNo := SeedDataExchange();
        LowerActor('BIFROST DataExch ori');
        AssertDiscoveryReads(0);
        RequestJson.Add('code', DefinitionCodeTok);
        ResponseJson := Dispatch(MessageType::"DataExchange.Definition.Get", RequestJson);
        AssertSuccess(ResponseJson);
        LibraryAssert.AreEqual(DefinitionCodeTok, ReadText(ReadData(ResponseJson), 'code'), 'The seeded definition was actually reached.');
        Clear(RequestJson);
        AssertSuccess(Dispatch(MessageType::"DataExchange.Definition.List", RequestJson));
        AssertSuccess(Dispatch(MessageType::"DataExchange.Type.List", RequestJson));
        AssertSuccess(Dispatch(MessageType::"DataExchange.Entry.List", RequestJson));
        RequestJson.Add('entryNo', EntryNo);
        RequestJson.Add('includeFields', true);
        RequestJson.Add('includeFileContent', true);
        ResponseJson := Dispatch(MessageType::"DataExchange.Entry.Get", RequestJson);
        AssertSuccess(ResponseJson);
        LibraryAssert.AreEqual(Encode('X79 data exchange bytes'), ReadText(ReadData(ResponseJson), 'contentBase64'), 'Actor sees exact persisted entry bytes.');
        Observe();
        AssertDataExchangeUnchanged(EntryNo);
    end;

    [Test]
    /// <summary>Registered Type.Set cannot modify a type under the advertised read-only discovery role.</summary>
    procedure Scenario_AC02_ReadOnlyTypeSet_PreservesGraph()
    var
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: #82 owns structured refusal implementation.
        AssertDataExchangeWriteDenial(MessageType::"DataExchange.Type.Set", false);
    end;

    [Test]
    /// <summary>Registered Import.Run cannot insert an entry under the discovery role.</summary>
    procedure Scenario_AC02_ReadOnlyImportRun_CreatesNoEntry()
    var
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: valid input must reach permission boundary.
        AssertDataExchangeWriteDenial(MessageType::"DataExchange.Import.Run", false);
    end;

    [Test]
    /// <summary>Registered Export.Run cannot insert an entry for a valid export definition under the discovery role.</summary>
    procedure Scenario_AC02_ReadOnlyExportRun_CreatesNoEntry()
    var
        MessageType: Enum "Message Type ori";
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: actual export type; no input-error substitute.
        AssertDataExchangeWriteDenial(MessageType::"DataExchange.Export.Run", true);
    end;

    // Each omission exercises the real seeded query graph, not an IsEnabled helper.
    [Test]
    /// <summary>Entry read omission preserves the seeded entry and its content.</summary>
    procedure Scenario_AC02_MissingEntryRead_PreservesGraph()
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: exact read omission.
        AssertDiscoveryDenial('Storage79 Entry ori', Database::"Data Exch.", true);
    end;

    [Test]
    /// <summary>Column read omission cannot produce an incomplete successful definition.</summary>
    procedure Scenario_AC02_MissingColumnRead_PreservesGraph()
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: nested query read.
        AssertDiscoveryDenial('Storage79 Column ori', Database::"Data Exch. Column Def", false);
    end;

    [Test]
    /// <summary>Definition read omission is isolated from every other discovery prerequisite.</summary>
    procedure Scenario_AC02_MissingDefinitionRead_PreservesGraph()
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: exact read omission.
        AssertDiscoveryDenial('Storage79 Def ori', Database::"Data Exch. Def", false);
    end;

    [Test]
    /// <summary>Field read omission refuses a seeded entry with fields requested.</summary>
    procedure Scenario_AC02_MissingFieldRead_PreservesGraph()
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: nested field read.
        AssertDiscoveryDenial('Storage79 Field ori', Database::"Data Exch. Field", true);
    end;

    [Test]
    /// <summary>Field mapping omission is denied on the actual definition graph.</summary>
    procedure Scenario_AC02_MissingFieldMappingRead_PreservesGraph()
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: nested mapping read.
        AssertDiscoveryDenial('Storage79 FldMap ori', Database::"Data Exch. Field Mapping", false);
    end;

    [Test]
    /// <summary>Line definition omission cannot silently produce an empty graph.</summary>
    procedure Scenario_AC02_MissingLineRead_PreservesGraph()
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: nested line read.
        AssertDiscoveryDenial('Storage79 Line ori', Database::"Data Exch. Line Def", false);
    end;

    [Test]
    /// <summary>Mapping omission is denied rather than returning partial definition data.</summary>
    procedure Scenario_AC02_MissingMappingRead_PreservesGraph()
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: nested mapping read.
        AssertDiscoveryDenial('Storage79 Map ori', Database::"Data Exch. Mapping", false);
    end;

    [Test]
    /// <summary>Type read omission is isolated and preserves the definition graph.</summary>
    procedure Scenario_AC02_MissingTypeRead_PreservesGraph()
    begin
        // Story79 AC02 | Time: independent of WorkDate | Risk: used-by type read.
        AssertDiscoveryDenial('Storage79 Type ori', Database::"Data Exchange Type", false);
    end;

    local procedure Initialize()
    var
        StorageSetup: Record "Storage Setup ori";
        Customer: Record Customer;
        DocumentAttachment: Record "Document Attachment";
        AttachmentLink: Record "Storage Attachment Link ori";
        UploadSession: Record "Storage Upload Session ori";
        MockState: Codeunit "Storage Mock State";
    begin
        // Setup/observer phases restore the runner's original grants, never claim actor authority.
        LowerPermissions.StopLoggingNAVPermissions();
        MockState.Reset();
        UploadSession.SetRange("File Name", 'X79-upload.txt');
        UploadSession.DeleteAll(true);
        DocumentAttachment.SetRange("Table ID", Database::Customer);
        DocumentAttachment.SetRange("No.", CustomerNoTok);
        DocumentAttachment.DeleteAll(false);
        AttachmentLink.SetRange("Storage Code", StorageCodeTok);
        AttachmentLink.DeleteAll(false);
        if StorageSetup.Get(StorageCodeTok) then
            StorageSetup.Delete(false);
        StorageSetup.Init();
        StorageSetup.Code := StorageCodeTok;
        StorageSetup.Description := 'X79 original setup';
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::Mock;
        StorageSetup."Base Path" := 'X79-root';
        StorageSetup.Enabled := true;
        StorageSetup.Insert(false);
        if not Customer.Get(CustomerNoTok) then begin
            Customer.Init();
            Customer."No." := CustomerNoTok;
            Customer.Insert(false);
        end;
    end;

    local procedure LowerActor(RoleId: Code[20])
    var
        Customer: Record Customer;
        RequestJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        // SetExact avoids Microsoft's Set()/Push defaults: All Objects, Test Tables, D365 Basic.
        LowerPermissions.StopLoggingNAVPermissions();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('Storage79 Test ori');
        LowerPermissions.AddPermissionSet('BIFROST API ori');
        LowerPermissions.AddPermissionSet(RoleId);
        LibraryAssert.IsTrue(LowerPermissions.HasChangedPermissions(), 'Permission enforcement must be active, never silently no-op.');
        LibraryAssert.IsFalse(Customer.WritePermission(), 'Canary detects inherited broad tabledata rights before dispatch.');
        // Actual Foundation role owns table/codeunit wildcard X. Test fixtures add none.
        AssertSuccess(Dispatch(MessageType::"Help.WhoAmI.Get", RequestJson));
    end;

    local procedure LowerStorageActor()
    begin
        LowerActor('BIFROST Attach ori');
    end;

    local procedure LowerNativeActor(AllowMutation: Boolean)
    begin
        LowerStorageActor();
        LowerPermissions.AddPermissionSet('Storage79 Target ori');
        if AllowMutation then
            LowerPermissions.AddPermissionSet('Storage79 Source ori');
    end;

    local procedure AddNativeBaseline()
    begin
        LowerPermissions.AddPermissionSet('Storage79 Source ori');
        LowerPermissions.AddPermissionSet('Storage79 Target ori');
    end;

    local procedure Observe()
    begin
        LowerPermissions.StopLoggingNAVPermissions();
    end;

    local procedure AssertReadOnlySetup()
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        LibraryAssert.IsTrue(StorageSetup.ReadPermission(), 'Setup read remains granted.');
        LibraryAssert.IsFalse(StorageSetup.WritePermission(), 'Setup mutation must be absent before the attempt.');
    end;

    local procedure AssertSetupUnchangedAsActor()
    begin
        Observe();
        AssertSetupUnchanged();
    end;

    local procedure AssertSetupUnchanged()
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        StorageSetup.ReadIsolation := IsolationLevel::ReadCommitted;
        StorageSetup.Get(StorageCodeTok);
        LibraryAssert.AreEqual('X79 original setup', StorageSetup.Description, 'Description must remain unchanged.');
        LibraryAssert.AreEqual('X79-root', StorageSetup."Base Path", 'Base path must remain unchanged.');
        LibraryAssert.IsTrue(StorageSetup.Enabled, 'Enabled state must remain unchanged.');
        LibraryAssert.IsTrue(IsNullGuid(StorageSetup."File Account Id"), 'No file account may be selected by a refused call.');
    end;

    local procedure AssertPlatformPermissionError()
    begin
        LibraryAssert.IsTrue(LowerCase(GetLastErrorText()).Contains('permission'), 'Failure must identify a genuine platform permission denial.');
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseText: Text;
        ResponseContentType: Text[100];
        MessageVersion: Enum "Message Version ori";
    begin
        // Public dispatcher only. Do not insert or call internal Foundation argument objects.
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        LibraryAssert.IsTrue(ResponseJson.ReadFrom(ResponseText), 'The dispatcher must return JSON.');
    end;

    local procedure AssertSuccess(ResponseJson: JsonObject)
    begin
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Actual dispatched operation must succeed with its role and prerequisites.');
    end;

    local procedure AssertStructuredError(ResponseJson: JsonObject; ExpectedCode: Text)
    begin
        LibraryAssert.AreEqual('Error', ReadText(ResponseJson, 'status'), 'The shipped operation must refuse this request.');
        LibraryAssert.AreEqual(ExpectedCode, ReadText(ResponseJson, 'code'), 'A license, missing input or earlier unrelated denial is not this test result.');
        LibraryAssert.AreNotEqual('', ReadText(ResponseJson, 'error'), 'Refusal must explain the reason.');
        LibraryAssert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'Refusal must provide an actionable next step.');
    end;

    local procedure ReadText(JsonObjectValue: JsonObject; PropertyName: Text): Text
    var
        PropertyToken: JsonToken;
    begin
        LibraryAssert.IsTrue(JsonObjectValue.Get(PropertyName, PropertyToken), 'Required response property is missing: ' + PropertyName);
        exit(PropertyToken.AsValue().AsText());
    end;

    local procedure ReadInteger(JsonObjectValue: JsonObject; PropertyName: Text): Integer
    var
        PropertyToken: JsonToken;
    begin
        LibraryAssert.IsTrue(JsonObjectValue.Get(PropertyName, PropertyToken), 'Required response property is missing: ' + PropertyName);
        exit(PropertyToken.AsValue().AsInteger());
    end;

    local procedure ReadData(ResponseJson: JsonObject): JsonObject
    var
        DataToken: JsonToken;
    begin
        LibraryAssert.IsTrue(ResponseJson.Get('data', DataToken), 'Successful dispatch must contain data.');
        exit(DataToken.AsObject());
    end;

    local procedure Encode(ContentText: Text): Text
    var
        Base64Convert: Codeunit "Base64 Convert";
    begin
        exit(Base64Convert.ToBase64(ContentText));
    end;

    local procedure MessageNames(MessageTypeName: Text) RequestedNames: JsonArray
    begin
        RequestedNames.Add(MessageTypeName);
    end;

    local procedure StorageRequest(StoragePath: Text) RequestJson: JsonObject
    begin
        RequestJson.Add('storageCode', StorageCodeTok);
        RequestJson.Add('path', StoragePath);
    end;

    local procedure CopyRequest(SourcePath: Text; TargetPath: Text) RequestJson: JsonObject
    begin
        RequestJson.Add('storageCode', StorageCodeTok);
        RequestJson.Add('sourcePath', SourcePath);
        RequestJson.Add('targetPath', TargetPath);
    end;

    local procedure BeginUpload(UseStorage: Boolean) UploadId: Guid
    var
        UploadIdText: Text;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        if UseStorage then
            RequestJson.Add('storageCode', StorageCodeTok);
        RequestJson.Add('fileName', 'X79-upload.txt');
        ResponseJson := Dispatch(MessageType::"Storage.Upload.Begin", RequestJson);
        AssertSuccess(ResponseJson);
        UploadIdText := ReadText(ReadData(ResponseJson), 'uploadId');
        LibraryAssert.IsTrue(Evaluate(UploadId, UploadIdText), 'Begin returns an actual upload id.');
        LibraryAssert.IsFalse(IsNullGuid(UploadId), 'Upload id must be nonempty.');
    end;

    local procedure AppendUpload(UploadId: Guid;
        SequenceNo: Integer;
        ContentText: Text)
    var
        RequestJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        RequestJson := UploadRequest(UploadId);
        RequestJson.Add('sequence', SequenceNo);
        RequestJson.Add('contentBase64', Encode(ContentText));
        AssertSuccess(Dispatch(MessageType::"Storage.Upload.Append", RequestJson));
    end;

    local procedure UploadRequest(UploadId: Guid) RequestJson: JsonObject
    begin
        RequestJson.Add('uploadId', Format(UploadId, 0, 4));
    end;

    local procedure NativeRequest(UploadId: Guid) RequestJson: JsonObject
    begin
        RequestJson := UploadRequest(UploadId);
        RequestJson.Add('tableId', Database::Customer);
        RequestJson.Add('no', CustomerNoTok);
    end;

    local procedure CreateAttachmentRequest() RequestJson: JsonObject
    begin
        RequestJson.Add('tableId', Database::Customer);
        RequestJson.Add('no', CustomerNoTok);
        RequestJson.Add('fileName', 'X79-inline.txt');
        RequestJson.Add('contentBase64', Encode('X79 inline bytes'));
    end;

    local procedure AttachmentRequest(AttachmentId: Guid) RequestJson: JsonObject
    begin
        RequestJson.Add('target', 'DocumentAttachment');
        RequestJson.Add('systemId', Format(AttachmentId, 0, 4));
    end;

    local procedure SeedNativeAttachment(var AttachmentId: Guid)
    var
        DocumentAttachment: Record "Document Attachment";
        MessageType: Enum "Message Type ori";
    begin
        AssertSuccess(Dispatch(MessageType::"Storage.Attachment.CreateForRecord", CreateAttachmentRequest()));
        DocumentAttachment.ReadIsolation := IsolationLevel::ReadCommitted;
        DocumentAttachment.SetRange("Table ID", Database::Customer);
        DocumentAttachment.SetRange("No.", CustomerNoTok);
        DocumentAttachment.SetRange("File Name", 'X79-inline');
        DocumentAttachment.FindFirst();
        AttachmentId := DocumentAttachment.SystemId;
    end;

    local procedure AssertNativeAttachments(ExpectedCount: Integer)
    var
        DocumentAttachment: Record "Document Attachment";
        Customer: Record Customer;
    begin
        Customer.ReadIsolation := IsolationLevel::ReadCommitted;
        Customer.Get(CustomerNoTok);
        LibraryAssert.AreEqual(CustomerNoTok, Customer."No.", 'Refused writes preserve the source record.');
        DocumentAttachment.ReadIsolation := IsolationLevel::ReadCommitted;
        DocumentAttachment.SetRange("Table ID", Database::Customer);
        DocumentAttachment.SetRange("No.", CustomerNoTok);
        LibraryAssert.AreEqual(ExpectedCount, DocumentAttachment.Count(), 'Fresh readback verifies actual native target rows.');
    end;

    local procedure AssertAttachmentBytes(FileName: Text; ContentText: Text)
    var
        DocumentAttachment: Record "Document Attachment";
    begin
        DocumentAttachment.ReadIsolation := IsolationLevel::ReadCommitted;
        DocumentAttachment.SetRange("Table ID", Database::Customer);
        DocumentAttachment.SetRange("No.", CustomerNoTok);
        DocumentAttachment.SetRange("File Name", FileName);
        DocumentAttachment.FindFirst();
        AssertOpenAttachmentBytes(DocumentAttachment, ContentText);
    end;

    local procedure AssertOpenAttachmentBytes(var DocumentAttachment: Record "Document Attachment"; ExpectedContent: Text)
    var
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        ContentInStream: InStream;
        ContentOutStream: OutStream;
    begin
        // Real base-app content export raises the shipped storage subscriber; no subscriber call.
        TempBlob.CreateOutStream(ContentOutStream);
        DocumentAttachment.ExportToStream(ContentOutStream);
        TempBlob.CreateInStream(ContentInStream);
        LibraryAssert.AreEqual(Encode(ExpectedContent), Base64Convert.ToBase64(ContentInStream), 'Native open must return exact persisted content.');
    end;

    local procedure AssertChunkBytes(var UploadChunk: Record "Storage Upload Chunk ori"; ExpectedContent: Text)
    var
        Base64Convert: Codeunit "Base64 Convert";
        ContentInStream: InStream;
    begin
        UploadChunk.CalcFields(Content);
        UploadChunk.Content.CreateInStream(ContentInStream);
        LibraryAssert.AreEqual(Encode(ExpectedContent), Base64Convert.ToBase64(ContentInStream), 'Denied write preserves persisted chunk bytes.');
    end;

    local procedure AssertDiscoveryDenial(RoleId: Code[20];
        OmittedTableId: Integer;
        UseEntry: Boolean)
    var
        EntryNo: Integer;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Initialize();
        EntryNo := SeedDataExchange();
        LowerActor(RoleId);
        AssertDiscoveryReads(OmittedTableId);
        if UseEntry then begin
            RequestJson.Add('entryNo', EntryNo);
            RequestJson.Add('includeFields', true);
            ResponseJson := Dispatch(MessageType::"DataExchange.Entry.Get", RequestJson);
        end else begin
            RequestJson.Add('code', DefinitionCodeTok);
            ResponseJson := Dispatch(MessageType::"DataExchange.Definition.Get", RequestJson);
        end;
        Observe();
        AssertDataExchangeUnchanged(EntryNo);
        AssertStructuredError(ResponseJson, 'PermissionDenied');
    end;

    local procedure AssertDataExchangeWriteDenial(MessageType: Enum "Message Type ori"; UseExportDefinition: Boolean)
    var
        DataExchDef: Record "Data Exch. Def";
        MockState: Codeunit "Storage Mock State";
        EntryNo: Integer;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        Initialize();
        EntryNo := SeedDataExchange();
        if UseExportDefinition then begin
            DataExchDef.Get(DefinitionCodeTok);
            DataExchDef.Type := DataExchDef.Type::"Generic Export";
            DataExchDef.Modify(false);
        end;
        MockState.PutFile('X79-input.txt', Encode('X79 import bytes'));
        LowerActor('BIFROST DataExch ori');
        LowerPermissions.AddPermissionSet('BIFROST Attach ori');
        AssertDiscoveryReads(0);
        RequestJson.Add('dataExchDefCode', DefinitionCodeTok);
        case MessageType of
            MessageType::"DataExchange.Type.Set":
                begin
                    RequestJson.Add('code', DefinitionCodeTok);
                    RequestJson.Add('description', 'X79 forbidden type modification');
                end;
            MessageType::"DataExchange.Import.Run":
                begin
                    RequestJson.Add('storageCode', StorageCodeTok);
                    RequestJson.Add('path', 'X79-input.txt');
                end;
            MessageType::"DataExchange.Export.Run":
                RequestJson.Add('fileName', 'X79-export.txt');
        end;
        ResponseJson := Dispatch(MessageType, RequestJson);
        Observe();
        AssertDataExchangeUnchanged(EntryNo);
        LibraryAssert.AreEqual(Encode('X79 import bytes'), MockState.GetFileContent('X79-input.txt'), 'Refused execution preserves the mock source bytes.');
        LibraryAssert.IsFalse(MockState.HasFile('X79-export.txt'), 'Refused execution creates no mock export file.');
        AssertStructuredError(ResponseJson, 'PermissionDenied');
    end;

    local procedure AssertDiscoveryReads(OmittedTableId: Integer)
    var
        DiscoveryRecordRef: RecordRef;
        TableIds: List of [Integer];
        TableId: Integer;
    begin
        TableIds.Add(Database::"Data Exch.");
        TableIds.Add(Database::"Data Exch. Column Def");
        TableIds.Add(Database::"Data Exch. Def");
        TableIds.Add(Database::"Data Exch. Field");
        TableIds.Add(Database::"Data Exch. Field Mapping");
        TableIds.Add(Database::"Data Exch. Line Def");
        TableIds.Add(Database::"Data Exch. Mapping");
        TableIds.Add(Database::"Data Exchange Type");
        foreach TableId in TableIds do begin
            DiscoveryRecordRef.Open(TableId);
            LibraryAssert.AreEqual(TableId <> OmittedTableId, DiscoveryRecordRef.ReadPermission(), 'Isolate exactly one effective read omission: ' + Format(TableId, 0, 9));
            LibraryAssert.IsFalse(DiscoveryRecordRef.WritePermission(), 'Discovery actors must have no mutation grant.');
            DiscoveryRecordRef.Close();
        end;
    end;

    local procedure SeedDataExchange(): Integer
    var
        DataExchDef: Record "Data Exch. Def";
        LineDef: Record "Data Exch. Line Def";
        ColumnDef: Record "Data Exch. Column Def";
        Mapping: Record "Data Exch. Mapping";
        FieldMapping: Record "Data Exch. Field Mapping";
        DataExchType: Record "Data Exchange Type";
        DataExch: Record "Data Exch.";
        DataExchField: Record "Data Exch. Field";
        ContentOutStream: OutStream;
    begin
        DataExch.SetRange("Data Exch. Def Code", DefinitionCodeTok);
        DataExch.DeleteAll(true);
        DataExch.Reset();
        if DataExchType.Get(DefinitionCodeTok) then
            DataExchType.Delete(false);
        if DataExchDef.Get(DefinitionCodeTok) then
            DataExchDef.Delete(true);
        DataExchDef.Init();
        DataExchDef.Code := DefinitionCodeTok;
        DataExchDef.Name := 'X79 seeded definition';
        DataExchDef.Type := DataExchDef.Type::"Generic Import";
        DataExchDef."File Type" := DataExchDef."File Type"::"Variable Text";
        DataExchDef.Insert(false);
        LineDef.Init();
        LineDef."Data Exch. Def Code" := DefinitionCodeTok;
        LineDef.Code := 'X79-LINE';
        LineDef."Column Count" := 1;
        LineDef.Insert(false);
        ColumnDef.Init();
        ColumnDef."Data Exch. Def Code" := DefinitionCodeTok;
        ColumnDef."Data Exch. Line Def Code" := LineDef.Code;
        ColumnDef."Column No." := 1;
        ColumnDef.Name := 'X79 column';
        ColumnDef.Insert(false);
        Mapping.Init();
        Mapping."Data Exch. Def Code" := DefinitionCodeTok;
        Mapping."Data Exch. Line Def Code" := LineDef.Code;
        Mapping."Table ID" := Database::Customer;
        Mapping.Insert(false);
        FieldMapping.Init();
        FieldMapping."Data Exch. Def Code" := DefinitionCodeTok;
        FieldMapping."Data Exch. Line Def Code" := LineDef.Code;
        FieldMapping."Table ID" := Database::Customer;
        FieldMapping."Column No." := 1;
        FieldMapping."Field ID" := 1;
        FieldMapping.Insert(false);
        DataExchType.Init();
        DataExchType.Code := DefinitionCodeTok;
        DataExchType.Description := 'X79 seeded type';
        DataExchType."Data Exch. Def. Code" := DefinitionCodeTok;
        DataExchType.Insert(false);
        DataExch.Init();
        DataExch."Data Exch. Def Code" := DefinitionCodeTok;
        DataExch."Data Exch. Line Def Code" := LineDef.Code;
        DataExch."File Name" := 'X79-entry.txt';
        DataExch."File Content".CreateOutStream(ContentOutStream, TextEncoding::UTF8);
        ContentOutStream.WriteText('X79 data exchange bytes');
        DataExch.Insert(false);
        DataExchField.Init();
        DataExchField."Data Exch. No." := DataExch."Entry No.";
        DataExchField."Line No." := 1;
        DataExchField."Column No." := 1;
        DataExchField.Value := CustomerNoTok;
        DataExchField.Insert(false);
        exit(DataExch."Entry No.");
    end;

    local procedure AssertDataExchangeUnchanged(EntryNo: Integer)
    var
        DataExchDef: Record "Data Exch. Def";
        LineDef: Record "Data Exch. Line Def";
        ColumnDef: Record "Data Exch. Column Def";
        Mapping: Record "Data Exch. Mapping";
        FieldMapping: Record "Data Exch. Field Mapping";
        DataExchType: Record "Data Exchange Type";
        DataExch: Record "Data Exch.";
        DataExchField: Record "Data Exch. Field";
        Base64Convert: Codeunit "Base64 Convert";
        ContentInStream: InStream;
    begin
        // Fresh observer records read every seeded graph component and the original blob.
        DataExchDef.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchDef.Get(DefinitionCodeTok);
        LibraryAssert.AreEqual('X79 seeded definition', DataExchDef.Name, 'Definition persists unchanged.');
        LineDef.ReadIsolation := IsolationLevel::ReadCommitted;
        LineDef.Get(DefinitionCodeTok, 'X79-LINE');
        LibraryAssert.AreEqual(1, LineDef."Column Count", 'Line definition persists unchanged.');
        ColumnDef.ReadIsolation := IsolationLevel::ReadCommitted;
        ColumnDef.Get(DefinitionCodeTok, 'X79-LINE', 1);
        LibraryAssert.AreEqual('X79 column', ColumnDef.Name, 'Column persists unchanged.');
        Mapping.ReadIsolation := IsolationLevel::ReadCommitted;
        Mapping.Get(DefinitionCodeTok, 'X79-LINE', Database::Customer);
        FieldMapping.ReadIsolation := IsolationLevel::ReadCommitted;
        FieldMapping.Get(DefinitionCodeTok, 'X79-LINE', Database::Customer, 1, 1);
        DataExchType.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchType.Get(DefinitionCodeTok);
        LibraryAssert.AreEqual(DefinitionCodeTok, DataExchType."Data Exch. Def. Code", 'Type reference persists unchanged.');
        LibraryAssert.AreEqual('X79 seeded type', DataExchType.Description, 'Denied Type.Set cannot change the type description.');
        DataExch.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExch.SetRange("Data Exch. Def Code", DefinitionCodeTok);
        LibraryAssert.AreEqual(1, DataExch.Count(), 'Denied entry writes must create no additional rows.');
        DataExch.Reset();
        DataExch.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExch.Get(EntryNo);
        DataExch.CalcFields("File Content");
        DataExch."File Content".CreateInStream(ContentInStream, TextEncoding::UTF8);
        LibraryAssert.AreEqual(Encode('X79 data exchange bytes'), Base64Convert.ToBase64(ContentInStream), 'Entry blob remains byte-for-byte intact.');
        DataExchField.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchField.Get(EntryNo, 1, 1, '');
        LibraryAssert.AreEqual(CustomerNoTok, DataExchField.Value, 'Entry field persists unchanged.');
    end;
}
