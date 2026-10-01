namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.Text;

/// <summary>
/// Tests for the chunked-upload message types (<c>Storage.Upload.Begin/Append/Commit/Abort/Status</c>),
/// driven through the in-memory mock storage backend. They cover the begin → append → commit
/// roundtrip, out-of-order and duplicate chunks, size and contiguity guards, abort, status, the
/// per-type help, that the upload tables are blocked from the generic Data.Records API, and
/// that <c>Data.Records.Set</c> on <c>Storage Setup ori</c> is refused while reads stay allowed.
/// </summary>
codeunit 96205 "Storage Upload Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        MockCodeTok: Label 'MOCK', Locked = true;
        TestCustNoTok: Label 'BIFTS-UPL-TST', Locked = true;

    [Test]
    procedure BeginAppendCommit_TwoChunks_RoundtripsContent()
    var
        TempArgument: Record "Message Argument ori";
        UploadId: Text;
        Path: Text;
    begin
        // [SCENARIO] A file delivered as two chunks is assembled and stored, byte-for-byte.
        Initialize();

        // [GIVEN] An open upload session
        BeginUpload('report.txt', '', UploadId, Path);

        // [WHEN] Two ordered chunks are appended and the session is committed
        AppendChunk(UploadId, 1, 'Hello ');
        AppendChunk(UploadId, 2, 'world');
        CommitUpload(TempArgument, UploadId);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Commit should succeed.');

        // [THEN] The stored file is the concatenation of the chunks, in order
        LibraryAssert.AreEqual('Hello world', GetStoredText(Path), 'The assembled file should match the chunk sequence.');
    end;

    [Test]
    procedure Commit_OutOfOrderChunks_AssemblesInSequence()
    var
        TempArgument: Record "Message Argument ori";
        UploadId: Text;
        Path: Text;
    begin
        // [SCENARIO] Chunks appended out of order are assembled by ascending sequence, not arrival.
        Initialize();
        BeginUpload('ordered.txt', '', UploadId, Path);

        // [WHEN] The later chunk is appended before the earlier one
        AppendChunk(UploadId, 2, 'world');
        AppendChunk(UploadId, 1, 'Hello ');
        CommitUpload(TempArgument, UploadId);

        // [THEN] Sequence order wins
        LibraryAssert.AreEqual('Hello world', GetStoredText(Path), 'Chunks should assemble in sequence order.');
    end;

    [Test]
    procedure Append_DuplicateSequence_ReplacesChunk()
    var
        TempArgument: Record "Message Argument ori";
        UploadId: Text;
        Path: Text;
    begin
        // [SCENARIO] Re-appending the same sequence replaces the chunk, so retries are safe.
        Initialize();
        BeginUpload('dup.txt', '', UploadId, Path);

        // [WHEN] Sequence 1 is appended twice with different content
        AppendChunk(UploadId, 1, 'AAAA');
        AppendChunk(TempArgument, UploadId, 1, 'BBBB');

        // [THEN] Only one chunk is counted, and commit stores the replacement
        LibraryAssert.AreEqual(1, ReadDataInt(TempArgument, 'chunkCount'), 'A duplicate sequence should replace, not add.');
        CommitUpload(TempArgument, UploadId);
        LibraryAssert.AreEqual('BBBB', GetStoredText(Path), 'The last write for a sequence should win.');
    end;

    [Test]
    procedure Commit_SizeMismatch_ReturnsError()
    var
        TempArgument: Record "Message Argument ori";
        BeginReq: JsonObject;
        UploadId: Text;
    begin
        // [SCENARIO] A declared size that does not match the received bytes blocks the commit.
        Initialize();

        // [GIVEN] A session that declares more bytes than will be sent
        BeginReq.Add('storageCode', MockCodeTok);
        BeginReq.Add('fileName', 'short.txt');
        BeginReq.Add('declaredSize', 999);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", BeginReq);
        UploadId := ReadDataText(TempArgument, 'uploadId');
        AppendChunk(UploadId, 1, 'x');

        // [WHEN] The session is committed
        CommitUpload(TempArgument, UploadId);

        // [THEN] It answers PreconditionFailed on declaredSize, and the session stays open for a retry
        AssertErrorResponse(TempArgument, 'PreconditionFailed', 'declaredSize');
    end;

    [Test]
    procedure Commit_NoChunks_ReturnsError()
    var
        TempArgument: Record "Message Argument ori";
        UploadId: Text;
        Path: Text;
    begin
        // [SCENARIO] Committing a session with no chunks is rejected.
        Initialize();
        BeginUpload('empty.txt', '', UploadId, Path);

        // [WHEN] Commit runs before any chunk is appended
        CommitUpload(TempArgument, UploadId);

        // [THEN] It answers PreconditionFailed on uploadId
        AssertErrorResponse(TempArgument, 'PreconditionFailed', 'uploadId');
    end;

    [Test]
    procedure Begin_FileNameWithFolder_ReturnsErrorAndCreatesNoSession()
    var
        Session: Record "Storage Upload Session ori";
        TempArgument: Record "Message Argument ori";
        BeginReq: JsonObject;
        LeafFileNameErr: Label 'fileName must be a file name without folders', Locked = true;
    begin
        // [SCENARIO] #16 AC01 — a fileName that contains folders is rejected and creates no session.
        Initialize();

        BeginReq.Add('storageCode', MockCodeTok);
        BeginReq.Add('fileName', 'bifrost-test/2026-09-12/chunked.bin');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", BeginReq);
        AssertErrorResponse(TempArgument, 'InvalidParameter', 'fileName');
        LibraryAssert.IsTrue(ReadText(TempArgument.GetResponseJson(), 'error').Contains(LeafFileNameErr), 'The error should say fileName must be a file name without folders.');

        Clear(BeginReq);
        BeginReq.Add('storageCode', MockCodeTok);
        BeginReq.Add('fileName', 'bifrost-test\chunked.bin');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", BeginReq);
        AssertErrorResponse(TempArgument, 'InvalidParameter', 'fileName');
        LibraryAssert.IsTrue(ReadText(TempArgument.GetResponseJson(), 'error').Contains(LeafFileNameErr), 'The error should say fileName must be a file name without folders.');

        Session.Reset();
        LibraryAssert.AreEqual(0, Session.Count(), 'A rejected fileName must not create an upload session.');
    end;

    [Test]
    procedure Begin_LeafFileNameWithFolderPath_UsesFolderPath()
    var
        UploadId: Text;
        Path: Text;
    begin
        // [SCENARIO] #16 AC02 — a leaf fileName plus folderPath stores the file at folderPath/fileName.
        Initialize();
        BeginUpload('chunked.bin', 'invoices/2026', UploadId, Path);
        LibraryAssert.AreEqual('invoices/2026/chunked.bin', Path, 'path should be folderPath/fileName.');
        LibraryAssert.AreNotEqual('', UploadId, 'Begin should return an uploadId.');
    end;

    [Test]
    procedure UploadBeginHelpStatesDefaultRoot()
    var
        BeginHelp: Text;
        Overview: Text;
        LeafFileNameErr: Label 'fileName must be a file name without folders', Locked = true;
        DefaultRootTok: Label 'bifrost-uploads/', Locked = true;
    begin
        // [SCENARIO] #16 — Upload.Begin help and the overview state the default root and the leaf-name rule.
        BeginHelp := MessageHelp(Enum::"Message Type ori"::"Storage.Upload.Begin");
        Overview := MessageHelp(Enum::"Message Type ori"::"Help.Storage.Get");
        LibraryAssert.IsTrue(BeginHelp.Contains(DefaultRootTok), 'Upload.Begin help should state the default root bifrost-uploads/.');
        LibraryAssert.IsTrue(BeginHelp.Contains(LeafFileNameErr), 'Upload.Begin help should document the leaf fileName error.');
        LibraryAssert.IsTrue(Overview.Contains(DefaultRootTok), 'The overview should state the default root bifrost-uploads/.');
    end;

    [Test]
    procedure Abort_OpenSession_RemovesSessionAndChunks()
    var
        TempArgument: Record "Message Argument ori";
        Session: Record "Storage Upload Session ori";
        Chunk: Record "Storage Upload Chunk ori";
        AbortReq: JsonObject;
        UploadId: Text;
        Path: Text;
    begin
        // [SCENARIO] Aborting an open session discards the session and its chunks.
        Initialize();
        BeginUpload('discard.txt', '', UploadId, Path);
        AppendChunk(UploadId, 1, 'data');

        // [WHEN] The session is aborted
        AbortReq.Add('uploadId', UploadId);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Abort", AbortReq);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Abort should succeed.');

        // [THEN] No session or chunk rows remain
        LibraryAssert.IsTrue(Session.IsEmpty(), 'The session should be deleted on abort.');
        LibraryAssert.IsTrue(Chunk.IsEmpty(), 'The chunks should be deleted on abort.');
    end;

    [Test]
    procedure Append_UnknownUploadId_ReturnsError()
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        AppendReq: JsonObject;
    begin
        // [SCENARIO] Appending to a session that does not exist is rejected.
        Initialize();

        // [GIVEN] A request naming an uploadId that was never opened
        AppendReq.Add('uploadId', Format(CreateGuid(), 0, 4));
        AppendReq.Add('sequence', 1);
        AppendReq.Add('contentBase64', Base64Convert.ToBase64('x'));

        // [WHEN] Storage.Upload.Append executes
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Append", AppendReq);

        // [THEN] It answers RecordNotFound on uploadId
        AssertErrorResponse(TempArgument, 'RecordNotFound', 'uploadId');
    end;

    [Test]
    procedure Status_OpenSession_ReportsProgress()
    var
        TempArgument: Record "Message Argument ori";
        StatusReq: JsonObject;
        UploadId: Text;
        Path: Text;
    begin
        // [SCENARIO] Status reports the received bytes, chunk count and open state.
        Initialize();
        BeginUpload('progress.txt', '', UploadId, Path);
        AppendChunk(UploadId, 1, 'abcde');

        // [WHEN] Storage.Upload.Status executes
        StatusReq.Add('uploadId', UploadId);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Status", StatusReq);

        // [THEN] It reports the progress so far
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Status should succeed.');
        LibraryAssert.AreEqual('Open', ReadDataText(TempArgument, 'status'), 'The session should be open.');
        LibraryAssert.AreEqual(5, ReadDataInt(TempArgument, 'received'), 'Five bytes were appended.');
        LibraryAssert.AreEqual(1, ReadDataInt(TempArgument, 'chunkCount'), 'One chunk was appended.');
    end;

    [Test]
    procedure CreateLinked_FromUploadedFile_AttachesToNewIncomingDoc()
    var
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
        Link: Record "Storage Attachment Link ori";
        TempArgument: Record "Message Argument ori";
        ContentBlob: Codeunit System.Utilities."Temp Blob";
        LinkReq: JsonObject;
        ContentInStream: InStream;
        UploadId: Text;
        Path: Text;
        EntryNo: Integer;
        SystemIdText: Text;
        SystemIdGuid: Guid;
        ReadBack: Text;
    begin
        // [SCENARIO] A file uploaded in chunks is attached to a new incoming document and served from storage.
        Initialize();

        // [GIVEN] A file assembled into storage via the chunked upload
        BeginUpload('LS-SSQ08189.pdf', '', UploadId, Path);
        AppendChunk(UploadId, 1, 'PDF-');
        AppendChunk(UploadId, 2, 'BODY');
        CommitUpload(TempArgument, UploadId);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Commit should succeed.');

        // [WHEN] Storage.Attachment.CreateLinked attaches it to a new incoming document
        Clear(TempArgument);
        LinkReq.Add('storageCode', MockCodeTok);
        LinkReq.Add('path', Path);
        LinkReq.Add('fileName', 'LS-SSQ08189.pdf');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateLinked", LinkReq);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'CreateLinked should succeed.');

        // [THEN] A new incoming document attachment exists, linked to storage
        EntryNo := ReadDataInt(TempArgument, 'incomingDocumentEntryNo');
        SystemIdText := ReadDataText(TempArgument, 'systemId');
        LibraryAssert.AreNotEqual(0, EntryNo, 'A new incoming document should have been created.');
        Evaluate(SystemIdGuid, SystemIdText);
        LibraryAssert.IsTrue(Link.Get(Database::"Incoming Document Attachment", SystemIdGuid), 'A storage link row should exist for the attachment.');
        LibraryAssert.AreEqual(Path, Link."Storage Path", 'The link should point at the uploaded file.');

        // [THEN] The attachment serves the original content transparently from storage
        IncomingDocumentAttachment.GetBySystemId(SystemIdGuid);
        LibraryAssert.IsTrue(IncomingDocumentAttachment.GetContent(ContentBlob), 'Content should be served from storage.');
        ContentBlob.CreateInStream(ContentInStream);
        ContentInStream.ReadText(ReadBack);
        LibraryAssert.AreEqual('PDF-BODY', ReadBack, 'The served content should match the uploaded chunks.');
    end;

    [Test]
    procedure Begin_WithoutStorageCode_CreatesBufferSession()
    var
        TempArgument: Record "Message Argument ori";
        BeginReq: JsonObject;
    begin
        // [SCENARIO] Begin without storageCode creates a buffer-only session.
        Initialize();
        BeginReq.Add('fileName', 'buffer.txt');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", BeginReq);

        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Buffer-only begin should succeed.');
        LibraryAssert.AreEqual('', ReadDataText(TempArgument, 'storageCode'), 'storageCode should be empty.');
        LibraryAssert.AreEqual('', ReadDataText(TempArgument, 'path'), 'path should be empty for buffer sessions.');
    end;

    [Test]
    procedure Commit_BufferSession_ReturnsNoStorageCodeError()
    var
        TempArgument: Record "Message Argument ori";
        BeginReq: JsonObject;
        CommitReq: JsonObject;
        UploadId: Text;
    begin
        // [SCENARIO] Commit on a buffer-only session fails because there is no storage target.
        Initialize();
        BeginReq.Add('fileName', 'buffer.txt');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", BeginReq);
        UploadId := ReadDataText(TempArgument, 'uploadId');
        AppendChunk(UploadId, 1, 'data');

        CommitReq.Add('uploadId', UploadId);
        Clear(TempArgument);
        TempArgument.Init();
        TempArgument."Type" := TempArgument."Type"::"Storage.Upload.Commit";
        TempArgument.Insert(true);

        CommitUpload(TempArgument, UploadId);
        AssertErrorResponse(TempArgument, 'PreconditionFailed', 'uploadId');
        LibraryAssert.IsTrue(ReadText(TempArgument.GetResponseJson(), 'nextStep').Contains('Storage.Upload.CommitToRecord'), 'The next step should point to CommitToRecord.');
    end;

    [Test]
    procedure CommitToRecord_OnCustomer_RoundtripsContent()
    var
        DocAttachment: Record "Document Attachment";
        TempArgument: Record "Message Argument ori";
        BeginReq: JsonObject;
        CommitReq: JsonObject;
        UploadId: Text;
    begin
        // [SCENARIO] Buffer upload committed to a customer creates a document attachment with correct content.
        Initialize();
        EnsureTestCustomer();

        BeginReq.Add('fileName', 'commit-to-record.txt');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", BeginReq);
        UploadId := ReadDataText(TempArgument, 'uploadId');

        AppendChunk(UploadId, 1, 'Hello ');
        AppendChunk(UploadId, 2, 'from CommitToRecord');

        CommitReq.Add('uploadId', UploadId);
        CommitReq.Add('tableId', Database::Customer);
        CommitReq.Add('no', TestCustNoTok);
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.CommitToRecord", CommitReq);

        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'CommitToRecord should succeed.');
        LibraryAssert.AreEqual('DocumentAttachment', ReadDataText(TempArgument, 'target'), 'target should be DocumentAttachment.');
        LibraryAssert.AreEqual(Format(false), Format(ReadDataBool(TempArgument, 'offloaded')), 'Content should be in database.');

        DocAttachment.SetRange("Table ID", Database::Customer);
        DocAttachment.SetRange("No.", TestCustNoTok);
        DocAttachment.SetRange("File Name", 'commit-to-record');
        LibraryAssert.AreEqual(1, DocAttachment.Count(), 'One attachment should exist.');
    end;

    [Test]
    procedure CommitToRecord_IncomingDocument_CreatesAttachment()
    var
        IncomingDocAttachment: Record "Incoming Document Attachment";
        TempArgument: Record "Message Argument ori";
        BeginReq: JsonObject;
        CommitReq: JsonObject;
        UploadId: Text;
        EntryNo: Integer;
    begin
        // [SCENARIO] Buffer upload committed as IncomingDocument creates an incoming document with attachment.
        Initialize();

        BeginReq.Add('fileName', 'incoming-upload.txt');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", BeginReq);
        UploadId := ReadDataText(TempArgument, 'uploadId');
        AppendChunk(UploadId, 1, 'Incoming document content');

        CommitReq.Add('uploadId', UploadId);
        CommitReq.Add('target', 'IncomingDocument');
        CommitReq.Add('description', 'Test incoming');
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.CommitToRecord", CommitReq);

        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'CommitToRecord should succeed.');
        LibraryAssert.AreEqual('IncomingDocument', ReadDataText(TempArgument, 'target'), 'target should be IncomingDocument.');
        EntryNo := ReadDataInt(TempArgument, 'incomingDocumentEntryNo');
        LibraryAssert.AreNotEqual(0, EntryNo, 'Should return an entry number.');

        IncomingDocAttachment.SetRange("Incoming Document Entry No.", EntryNo);
        LibraryAssert.AreEqual(1, IncomingDocAttachment.Count(), 'One attachment should exist on the incoming document.');
    end;

    [Test]
    procedure CommitToRecord_UnknownTarget_ReturnsError()
    var
        TempArgument: Record "Message Argument ori";
        BeginReq: JsonObject;
        CommitReq: JsonObject;
        UploadId: Text;
    begin
        // [SCENARIO] CommitToRecord with an invalid target returns an error.
        Initialize();
        BeginReq.Add('fileName', 'bad-target.txt');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", BeginReq);
        UploadId := ReadDataText(TempArgument, 'uploadId');
        AppendChunk(UploadId, 1, 'data');

        CommitReq.Add('uploadId', UploadId);
        CommitReq.Add('target', 'SomethingInvalid');
        CommitReq.Add('tableId', Database::Customer);
        CommitReq.Add('no', TestCustNoTok);

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.CommitToRecord", CommitReq);
        AssertErrorResponse(TempArgument, 'InvalidParameter', 'target');
    end;

    [Test]
    procedure CommitToRecord_NoChunks_ReturnsError()
    var
        TempArgument: Record "Message Argument ori";
        BeginReq: JsonObject;
        CommitReq: JsonObject;
        UploadId: Text;
    begin
        // [SCENARIO] CommitToRecord without appending any chunks fails.
        Initialize();
        BeginReq.Add('fileName', 'empty.txt');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", BeginReq);
        UploadId := ReadDataText(TempArgument, 'uploadId');

        CommitReq.Add('uploadId', UploadId);
        CommitReq.Add('tableId', Database::Customer);
        CommitReq.Add('no', TestCustNoTok);

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.CommitToRecord", CommitReq);
        AssertErrorResponse(TempArgument, 'PreconditionFailed', 'uploadId');
    end;

    [Test]
    procedure UploadTables_AreRestrictedFromDataRecords()
    var
        TempArgument: Record "Message Argument ori";
    begin
        // [SCENARIO] The upload tables are blocked from the generic Data.Records.* message types.
        Initialize();

        // [THEN] Both tables report read- and write-restricted
        LibraryAssert.IsTrue(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Storage Upload Session ori"), 'Sessions must be read-restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Upload Session ori"), 'Sessions must be write-restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Storage Upload Chunk ori"), 'Chunks must be read-restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Upload Chunk ori"), 'Chunks must be write-restricted.');
    end;

    [Test]
    procedure DataRecordsSet_OnStorageSetup_ReturnsError()
    var
        StorageSetup: Record "Storage Setup ori";
        TempArgument: Record "Message Argument ori";
        SetRequest: JsonObject;
        GetRequest: JsonObject;
        RecordObject: JsonObject;
        PrimaryKey: JsonObject;
        Fields: JsonObject;
        DataArray: JsonArray;
        ResponseJson: JsonObject;
        ResultArray: JsonArray;
        ResultToken: JsonToken;
        RecordToken: JsonToken;
        PrimaryKeyToken: JsonToken;
        OriginalDescription: Text[100];
    begin
        // [SCENARIO] S6 AC01 (#19): Data.Records.Set on Storage Setup ori returns an error.
        // Reading that table through Data.Records.Get still succeeds.
        Initialize();
        StorageSetup.Get(MockCodeTok);
        OriginalDescription := StorageSetup.Description;

        // [GIVEN] A generic write that would change the setup description
        PrimaryKey.Add('Code', MockCodeTok);
        Fields.Add('Description', 'tampered by Data.Records.Set');
        RecordObject.Add('primaryKey', PrimaryKey);
        RecordObject.Add('fields', Fields);
        DataArray.Add(RecordObject);
        SetRequest.Add('tableName', 'Storage Setup ori');
        SetRequest.Add('data', DataArray);

        // [WHEN] Data.Records.Set is invoked against Storage Setup ori
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Data.Records.Set", SetRequest);

        // [THEN] The message type returns an error and the row is unchanged
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Error', ReadText(ResponseJson, 'status'), 'Data.Records.Set on Storage Setup ori must return an error.');
        LibraryAssert.IsTrue(
            ReadText(ResponseJson, 'error').Contains('cannot be written'),
            'The error should say the table cannot be written via Data.Records.Set.');
        StorageSetup.Get(MockCodeTok);
        LibraryAssert.AreEqual(OriginalDescription, StorageSetup.Description, 'Storage Setup ori must be unchanged after the rejected write.');

        // [WHEN] The same table is read through Data.Records.Get
        GetRequest.Add('tableName', 'Storage Setup ori');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Data.Records.Get", GetRequest);

        // [THEN] The read succeeds and returns the setup row
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Data.Records.Get on Storage Setup ori must succeed.');
        LibraryAssert.IsTrue(ResponseJson.Get('result', ResultToken), 'The read response should contain result.');
        ResultArray := ResultToken.AsArray();
        LibraryAssert.AreEqual(1, ResultArray.Count(), 'The setup row should be returned.');
        ResultArray.Get(0, RecordToken);
        RecordObject := RecordToken.AsObject();
        LibraryAssert.IsTrue(RecordObject.Get('primaryKey', PrimaryKeyToken), 'The returned row should include its primary key.');
        LibraryAssert.AreEqual(MockCodeTok, ReadObjText(PrimaryKeyToken.AsObject(), 'Code'), 'The returned row should be the setup connection.');
    end;

    [Test]
    procedure UploadMessageTypes_HaveMetadataAndHelp()
    var
        MessageType: Enum "Message Type ori";
        Ordinals: List of [Integer];
        Ordinal: Integer;
    begin
        // [SCENARIO] Every upload/link message type (Storage.Upload.Begin to Storage.Upload.CommitToRecord) exposes metadata and a contract.
        Initialize();
        Ordinals := MessageType.Ordinals();
        foreach Ordinal in Ordinals do
            if (Ordinal >= Enum::"Message Type ori"::"Storage.Upload.Begin".AsInteger()) and (Ordinal <= Enum::"Message Type ori"::"Storage.Upload.CommitToRecord".AsInteger()) then
                VerifyTypeMetadataAndHelp(Ordinal);
    end;

    local procedure VerifyTypeMetadataAndHelp(Ordinal: Integer)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        MsgInterface: Interface "Msg Interface ori";
        ExpectedDirection: Enum "Msg Direction ori";
        Contract: JsonObject;
        WrongDirectionErr: Label 'Type %1 has the wrong message direction.', Comment = '%1 = message type';
        NoContractErr: Label 'Type %1 should describe itself through its contract.', Comment = '%1 = message type';
    begin
        MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
        MsgInterface := MessageType;

        // Every upload and link type writes Business Central data; only Storage.Upload.Status reads.
        if MessageType = MessageType::"Storage.Upload.Status" then
            ExpectedDirection := ExpectedDirection::Outbound
        else
            ExpectedDirection := ExpectedDirection::Inbound;
        LibraryAssert.AreEqual(ExpectedDirection, MsgInterface.GetMessageDirection(), StrSubstNo(WrongDirectionErr, MessageType));
        LibraryAssert.IsTrue(ContractMgt.GetContract(MessageType, Contract), StrSubstNo(NoContractErr, MessageType));
    end;

    local procedure MessageHelp(MessageType: Enum "Message Type ori") Result: Text
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
    begin
        ContractMgt.GetContract(MessageType, Contract);
        Contract.WriteTo(Result);
    end;

    local procedure Initialize()
    var
        StorageSetup: Record "Storage Setup ori";
        Session: Record "Storage Upload Session ori";
        MockState: Codeunit "Storage Mock State";
    begin
        MockState.Reset();
        Session.DeleteAll(true);
        StorageSetup.DeleteAll();
        StorageSetup.Init();
        StorageSetup."Code" := MockCodeTok;
        StorageSetup.Description := 'Mock storage connection';
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::Mock;
        StorageSetup.Enabled := true;
        StorageSetup.Insert();
    end;

    local procedure EnsureTestCustomer()
    var
        Customer: Record Customer;
    begin
        if not Customer.Get(TestCustNoTok) then begin
            Customer.Init();
            Customer."No." := TestCustNoTok;
            Customer.Insert(true);
        end;
    end;

    local procedure BeginUpload(FileName: Text; FolderPath: Text; var UploadId: Text; var Path: Text)
    var
        TempArgument: Record "Message Argument ori";
        BeginReq: JsonObject;
    begin
        BeginReq.Add('storageCode', MockCodeTok);
        BeginReq.Add('fileName', FileName);
        if FolderPath <> '' then
            BeginReq.Add('folderPath', FolderPath);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", BeginReq);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Begin should succeed.');
        UploadId := ReadDataText(TempArgument, 'uploadId');
        Path := ReadDataText(TempArgument, 'path');
    end;

    local procedure AppendChunk(UploadId: Text; SequenceNo: Integer; ContentText: Text)
    var
        TempArgument: Record "Message Argument ori";
    begin
        AppendChunk(TempArgument, UploadId, SequenceNo, ContentText);
    end;

    local procedure AppendChunk(var TempArgument: Record "Message Argument ori"; UploadId: Text; SequenceNo: Integer; ContentText: Text)
    var
        Base64Convert: Codeunit "Base64 Convert";
        AppendReq: JsonObject;
    begin
        AppendReq.Add('uploadId', UploadId);
        AppendReq.Add('sequence', SequenceNo);
        AppendReq.Add('contentBase64', Base64Convert.ToBase64(ContentText));
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Append", AppendReq);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Append should succeed.');
    end;

    local procedure CommitUpload(var TempArgument: Record "Message Argument ori"; UploadId: Text)
    var
        CommitReq: JsonObject;
    begin
        Clear(TempArgument);
        CommitReq.Add('uploadId', UploadId);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Commit", CommitReq);
    end;

    local procedure GetStoredText(Path: Text): Text
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        TempBlob: Codeunit System.Utilities."Temp Blob";
        GetReq: JsonObject;
        ContentOutStream: OutStream;
        ContentInStream: InStream;
        Result: Text;
    begin
        GetReq.Add('storageCode', MockCodeTok);
        GetReq.Add('path', Path);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Get", GetReq);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'File get should succeed.');
        TempBlob.CreateOutStream(ContentOutStream);
        Base64Convert.FromBase64(ReadDataText(TempArgument, 'contentBase64'), ContentOutStream);
        TempBlob.CreateInStream(ContentInStream);
        ContentInStream.ReadText(Result);
        exit(Result);
    end;

    local procedure ExecuteTypeWithRequest(var TempArgument: Record "Message Argument ori"; MessageType: Enum "Message Type ori"; RequestJson: JsonObject)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[50];
        MessageVersion: Enum "Message Version ori";
        RequestText: Text;
        ResponseText: Text;
        ResponseJson: JsonObject;
    begin
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        ResponseJson.ReadFrom(ResponseText);
        // Clear PK before Insert: Init keeps ID; reuse after a prior Insert raises
        // "Message Argument ori already exists" (attachments#31 smoking gun).
        Clear(TempArgument);
        TempArgument.Init();
        TempArgument."Type" := MessageType;
        TempArgument.Insert(true);
        TempArgument.SetResponseJson(ResponseJson);
    end;

    local procedure ReadData(ResponseJson: JsonObject) DataObject: JsonObject
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get('data', Token) then
            if Token.IsObject() then
                DataObject := Token.AsObject();
    end;

    local procedure ReadDataText(var TempArgument: Record "Message Argument ori"; PropertyName: Text): Text
    begin
        exit(ReadObjText(ReadData(TempArgument.GetResponseJson()), PropertyName));
    end;

    local procedure ReadDataInt(var TempArgument: Record "Message Argument ori"; PropertyName: Text): Integer
    var
        DataObject: JsonObject;
        Token: JsonToken;
    begin
        DataObject := ReadData(TempArgument.GetResponseJson());
        if DataObject.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsInteger());
        exit(0);
    end;

    local procedure ReadDataBool(var TempArgument: Record "Message Argument ori"; PropertyName: Text): Boolean
    var
        DataObject: JsonObject;
        Token: JsonToken;
    begin
        DataObject := ReadData(TempArgument.GetResponseJson());
        if DataObject.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsBoolean());
        exit(false);
    end;

    local procedure ReadObjText(JsonObj: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadText(JsonObj: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure AssertErrorResponse(var TempArgument: Record "Message Argument ori"; ExpectedCode: Text; ExpectedParameter: Text)
    var
        ResponseJson: JsonObject;
        WrongCodeErr: Label 'Expected an error with code %1.', Comment = '%1 = error code', Locked = true;
        WrongParameterErr: Label 'Expected the error to name parameter %1.', Comment = '%1 = parameter', Locked = true;
    begin
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Error', ReadText(ResponseJson, 'status'), 'The call should answer with an error response.');
        LibraryAssert.AreEqual(ExpectedCode, ReadText(ResponseJson, 'code'), StrSubstNo(WrongCodeErr, ExpectedCode));
        if ExpectedParameter <> '' then
            LibraryAssert.AreEqual(ExpectedParameter, ReadText(ResponseJson, 'parameter'), StrSubstNo(WrongParameterErr, ExpectedParameter));
    end;
}
