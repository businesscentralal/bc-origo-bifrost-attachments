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
/// per-type help, and that the upload tables are blocked from the generic Data.Records API.
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
        Argument: Record "Message Argument ori";
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
        CommitUpload(Argument, UploadId);
        LibraryAssert.AreEqual('Success', ReadText(Argument.GetResponseJson(), 'status'), 'Commit should succeed.');

        // [THEN] The stored file is the concatenation of the chunks, in order
        LibraryAssert.AreEqual('Hello world', GetStoredText(Path), 'The assembled file should match the chunk sequence.');
    end;

    [Test]
    procedure Commit_OutOfOrderChunks_AssemblesInSequence()
    var
        Argument: Record "Message Argument ori";
        UploadId: Text;
        Path: Text;
    begin
        // [SCENARIO] Chunks appended out of order are assembled by ascending sequence, not arrival.
        Initialize();
        BeginUpload('ordered.txt', '', UploadId, Path);

        // [WHEN] The later chunk is appended before the earlier one
        AppendChunk(UploadId, 2, 'world');
        AppendChunk(UploadId, 1, 'Hello ');
        CommitUpload(Argument, UploadId);

        // [THEN] Sequence order wins
        LibraryAssert.AreEqual('Hello world', GetStoredText(Path), 'Chunks should assemble in sequence order.');
    end;

    [Test]
    procedure Append_DuplicateSequence_ReplacesChunk()
    var
        Argument: Record "Message Argument ori";
        UploadId: Text;
        Path: Text;
    begin
        // [SCENARIO] Re-appending the same sequence replaces the chunk, so retries are safe.
        Initialize();
        BeginUpload('dup.txt', '', UploadId, Path);

        // [WHEN] Sequence 1 is appended twice with different content
        AppendChunk(UploadId, 1, 'AAAA');
        AppendChunk(Argument, UploadId, 1, 'BBBB');

        // [THEN] Only one chunk is counted, and commit stores the replacement
        LibraryAssert.AreEqual(1, ReadDataInt(Argument, 'chunkCount'), 'A duplicate sequence should replace, not add.');
        CommitUpload(Argument, UploadId);
        LibraryAssert.AreEqual('BBBB', GetStoredText(Path), 'The last write for a sequence should win.');
    end;

    [Test]
    procedure Commit_SizeMismatch_ReturnsError()
    var
        Argument: Record "Message Argument ori";
        BeginReq: JsonObject;
        UploadId: Text;
    begin
        // [SCENARIO] A declared size that does not match the received bytes blocks the commit.
        Initialize();

        // [GIVEN] A session that declares more bytes than will be sent
        BeginReq.Add('storageCode', MockCodeTok);
        BeginReq.Add('fileName', 'short.txt');
        BeginReq.Add('declaredSize', 999);
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Begin", BeginReq);
        UploadId := ReadDataText(Argument, 'uploadId');
        AppendChunk(UploadId, 1, 'x');

        // [WHEN] The session is committed
        // [THEN] It raises an error (the framework turns a raised error into an Error envelope at runtime)
        asserterror CommitUpload(Argument, UploadId);
        LibraryAssert.ExpectedError('does not match the declared size');
    end;

    [Test]
    procedure Commit_NoChunks_ReturnsError()
    var
        Argument: Record "Message Argument ori";
        UploadId: Text;
        Path: Text;
    begin
        // [SCENARIO] Committing a session with no chunks is rejected.
        Initialize();
        BeginUpload('empty.txt', '', UploadId, Path);

        // [WHEN] Commit runs before any chunk is appended
        // [THEN] It raises an error (the framework turns a raised error into an Error envelope at runtime)
        asserterror CommitUpload(Argument, UploadId);
        LibraryAssert.ExpectedError('no chunks to commit');
    end;

    [Test]
    procedure Abort_OpenSession_RemovesSessionAndChunks()
    var
        Argument: Record "Message Argument ori";
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
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Abort", AbortReq);
        LibraryAssert.AreEqual('Success', ReadText(Argument.GetResponseJson(), 'status'), 'Abort should succeed.');

        // [THEN] No session or chunk rows remain
        LibraryAssert.IsTrue(Session.IsEmpty(), 'The session should be deleted on abort.');
        LibraryAssert.IsTrue(Chunk.IsEmpty(), 'The chunks should be deleted on abort.');
    end;

    [Test]
    procedure Append_UnknownUploadId_ReturnsError()
    var
        Argument: Record "Message Argument ori";
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
        // [THEN] It raises an error (the framework turns a raised error into an Error envelope at runtime)
        asserterror ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Append", AppendReq);
        LibraryAssert.ExpectedError('No upload session was found');
    end;

    [Test]
    procedure Status_OpenSession_ReportsProgress()
    var
        Argument: Record "Message Argument ori";
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
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Status", StatusReq);

        // [THEN] It reports the progress so far
        LibraryAssert.AreEqual('Success', ReadText(Argument.GetResponseJson(), 'status'), 'Status should succeed.');
        LibraryAssert.AreEqual('Open', ReadDataText(Argument, 'status'), 'The session should be open.');
        LibraryAssert.AreEqual(5, ReadDataInt(Argument, 'received'), 'Five bytes were appended.');
        LibraryAssert.AreEqual(1, ReadDataInt(Argument, 'chunkCount'), 'One chunk was appended.');
    end;

    [Test]
    procedure CreateLinked_FromUploadedFile_AttachesToNewIncomingDoc()
    var
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
        Link: Record "Storage Attachment Link ori";
        Argument: Record "Message Argument ori";
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
        CommitUpload(Argument, UploadId);
        LibraryAssert.AreEqual('Success', ReadText(Argument.GetResponseJson(), 'status'), 'Commit should succeed.');

        // [WHEN] Storage.Attachment.CreateLinked attaches it to a new incoming document
        Clear(Argument);
        LinkReq.Add('storageCode', MockCodeTok);
        LinkReq.Add('path', Path);
        LinkReq.Add('fileName', 'LS-SSQ08189.pdf');
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Attachment.CreateLinked", LinkReq);
        LibraryAssert.AreEqual('Success', ReadText(Argument.GetResponseJson(), 'status'), 'CreateLinked should succeed.');

        // [THEN] A new incoming document attachment exists, linked to storage
        EntryNo := ReadDataInt(Argument, 'incomingDocumentEntryNo');
        SystemIdText := ReadDataText(Argument, 'systemId');
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
        Argument: Record "Message Argument ori";
        BeginReq: JsonObject;
    begin
        // [SCENARIO] Begin without storageCode creates a buffer-only session.
        Initialize();
        BeginReq.Add('fileName', 'buffer.txt');
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Begin", BeginReq);

        LibraryAssert.AreEqual('Success', ReadText(Argument.GetResponseJson(), 'status'), 'Buffer-only begin should succeed.');
        LibraryAssert.AreEqual('', ReadDataText(Argument, 'storageCode'), 'storageCode should be empty.');
        LibraryAssert.AreEqual('', ReadDataText(Argument, 'path'), 'path should be empty for buffer sessions.');
    end;

    [Test]
    procedure Commit_BufferSession_ReturnsNoStorageCodeError()
    var
        Argument: Record "Message Argument ori";
        BeginReq: JsonObject;
        CommitReq: JsonObject;
        UploadId: Text;
    begin
        // [SCENARIO] Commit on a buffer-only session fails because there is no storage target.
        Initialize();
        BeginReq.Add('fileName', 'buffer.txt');
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Begin", BeginReq);
        UploadId := ReadDataText(Argument, 'uploadId');
        AppendChunk(UploadId, 1, 'data');

        CommitReq.Add('uploadId', UploadId);
        Clear(Argument);
        Argument.Init();
        Argument."Type" := Argument."Type"::"Storage.Upload.Commit";
        Argument.Insert(true);

        asserterror CommitUpload(Argument, UploadId);
        LibraryAssert.ExpectedError('no storage connection');
    end;

    [Test]
    procedure CommitToRecord_OnCustomer_RoundtripsContent()
    var
        DocAttachment: Record "Document Attachment";
        Argument: Record "Message Argument ori";
        BeginReq: JsonObject;
        CommitReq: JsonObject;
        UploadId: Text;
    begin
        // [SCENARIO] Buffer upload committed to a customer creates a document attachment with correct content.
        Initialize();
        EnsureTestCustomer();

        BeginReq.Add('fileName', 'commit-to-record.txt');
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Begin", BeginReq);
        UploadId := ReadDataText(Argument, 'uploadId');

        AppendChunk(UploadId, 1, 'Hello ');
        AppendChunk(UploadId, 2, 'from CommitToRecord');

        CommitReq.Add('uploadId', UploadId);
        CommitReq.Add('tableId', Database::Customer);
        CommitReq.Add('no', TestCustNoTok);
        Clear(Argument);
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.CommitToRecord", CommitReq);

        LibraryAssert.AreEqual('Success', ReadText(Argument.GetResponseJson(), 'status'), 'CommitToRecord should succeed.');
        LibraryAssert.AreEqual('DocumentAttachment', ReadDataText(Argument, 'target'), 'target should be DocumentAttachment.');
        LibraryAssert.AreEqual(Format(false), Format(ReadDataBool(Argument, 'offloaded')), 'Content should be in database.');

        DocAttachment.SetRange("Table ID", Database::Customer);
        DocAttachment.SetRange("No.", TestCustNoTok);
        DocAttachment.SetRange("File Name", 'commit-to-record');
        LibraryAssert.AreEqual(1, DocAttachment.Count(), 'One attachment should exist.');
    end;

    [Test]
    procedure CommitToRecord_IncomingDocument_CreatesAttachment()
    var
        IncomingDocAttachment: Record "Incoming Document Attachment";
        Argument: Record "Message Argument ori";
        BeginReq: JsonObject;
        CommitReq: JsonObject;
        UploadId: Text;
        EntryNo: Integer;
    begin
        // [SCENARIO] Buffer upload committed as IncomingDocument creates an incoming document with attachment.
        Initialize();

        BeginReq.Add('fileName', 'incoming-upload.txt');
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Begin", BeginReq);
        UploadId := ReadDataText(Argument, 'uploadId');
        AppendChunk(UploadId, 1, 'Incoming document content');

        CommitReq.Add('uploadId', UploadId);
        CommitReq.Add('target', 'IncomingDocument');
        CommitReq.Add('description', 'Test incoming');
        Clear(Argument);
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.CommitToRecord", CommitReq);

        LibraryAssert.AreEqual('Success', ReadText(Argument.GetResponseJson(), 'status'), 'CommitToRecord should succeed.');
        LibraryAssert.AreEqual('IncomingDocument', ReadDataText(Argument, 'target'), 'target should be IncomingDocument.');
        EntryNo := ReadDataInt(Argument, 'incomingDocumentEntryNo');
        LibraryAssert.AreNotEqual(0, EntryNo, 'Should return an entry number.');

        IncomingDocAttachment.SetRange("Incoming Document Entry No.", EntryNo);
        LibraryAssert.AreEqual(1, IncomingDocAttachment.Count(), 'One attachment should exist on the incoming document.');
    end;

    [Test]
    procedure CommitToRecord_UnknownTarget_ReturnsError()
    var
        Argument: Record "Message Argument ori";
        BeginReq: JsonObject;
        CommitReq: JsonObject;
        UploadId: Text;
    begin
        // [SCENARIO] CommitToRecord with an invalid target returns an error.
        Initialize();
        BeginReq.Add('fileName', 'bad-target.txt');
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Begin", BeginReq);
        UploadId := ReadDataText(Argument, 'uploadId');
        AppendChunk(UploadId, 1, 'data');

        CommitReq.Add('uploadId', UploadId);
        CommitReq.Add('target', 'SomethingInvalid');
        CommitReq.Add('tableId', Database::Customer);
        CommitReq.Add('no', TestCustNoTok);

        asserterror ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.CommitToRecord", CommitReq);
        LibraryAssert.ExpectedError('Unknown target');
    end;

    [Test]
    procedure CommitToRecord_NoChunks_ReturnsError()
    var
        Argument: Record "Message Argument ori";
        BeginReq: JsonObject;
        CommitReq: JsonObject;
        UploadId: Text;
    begin
        // [SCENARIO] CommitToRecord without appending any chunks fails.
        Initialize();
        BeginReq.Add('fileName', 'empty.txt');
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Begin", BeginReq);
        UploadId := ReadDataText(Argument, 'uploadId');

        CommitReq.Add('uploadId', UploadId);
        CommitReq.Add('tableId', Database::Customer);
        CommitReq.Add('no', TestCustNoTok);

        asserterror ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.CommitToRecord", CommitReq);
        LibraryAssert.ExpectedError('no chunks');
    end;

    [Test]
    procedure UploadTables_AreRestrictedFromDataRecords()
    var
        Argument: Record "Message Argument ori";
    begin
        // [SCENARIO] The upload tables are blocked from the generic Data.Records.* message types.
        Initialize();

        // [THEN] Both tables report read- and write-restricted
        LibraryAssert.IsTrue(Argument.IsTableReadRestrictedForDataRecords(Database::"Storage Upload Session ori"), 'Sessions must be read-restricted.');
        LibraryAssert.IsTrue(Argument.IsTableWriteRestrictedForDataRecords(Database::"Storage Upload Session ori"), 'Sessions must be write-restricted.');
        LibraryAssert.IsTrue(Argument.IsTableReadRestrictedForDataRecords(Database::"Storage Upload Chunk ori"), 'Chunks must be read-restricted.');
        LibraryAssert.IsTrue(Argument.IsTableWriteRestrictedForDataRecords(Database::"Storage Upload Chunk ori"), 'Chunks must be write-restricted.');
    end;

    [Test]
    procedure UploadMessageTypes_HaveMetadataAndHelp()
    var
        MessageType: Enum "Message Type ori";
        Ordinals: List of [Integer];
        Ordinal: Integer;
    begin
        // [SCENARIO] Every upload/link message type (72635-72641) exposes metadata and self-identifying help.
        Initialize();
        Ordinals := MessageType.Ordinals();
        foreach Ordinal in Ordinals do
            if (Ordinal >= 72635) and (Ordinal <= 72641) then
                VerifyTypeMetadataAndHelp(Ordinal);
    end;

    local procedure VerifyTypeMetadataAndHelp(Ordinal: Integer)
    var
        Argument: Record "Message Argument ori";
        MessageType: Enum "Message Type ori";
        MsgInterface: Interface "Msg Interface ori";
        ExpectedDirection: Enum "Msg Direction ori";
        HelpText: Text;
        TypeName: Text;
        WrongDirectionErr: Label 'Type %1 has the wrong message direction.', Comment = '%1 = message type';
        NoHelpErr: Label 'Type %1 should produce help markdown.', Comment = '%1 = message type';
        NotMarkdownErr: Label 'Type %1 help should start with a Markdown heading.', Comment = '%1 = message type';
        NotSelfIdentifyingErr: Label 'Type %1 help should name the message type.', Comment = '%1 = message type';
    begin
        MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
        TypeName := MessageTypeName(MessageType);
        Argument.Init();
        Argument."Type" := MessageType;
        Argument.Insert(true);
        MsgInterface := Argument.GetMessageTypeInterface();

        // Begin/Append/Commit/Abort (72635-72638) write; Status (72639) reads.
        if Ordinal = 72639 then
            ExpectedDirection := ExpectedDirection::Outbound
        else
            ExpectedDirection := ExpectedDirection::Inbound;
        LibraryAssert.AreEqual(ExpectedDirection, MsgInterface.GetMessageDirection(), StrSubstNo(WrongDirectionErr, MessageType));

        MsgInterface.GetMessageHelpAsMarkdownDocument(Argument);
        HelpText := Argument.GetResponseText();
        LibraryAssert.AreNotEqual('', HelpText, StrSubstNo(NoHelpErr, MessageType));
        LibraryAssert.IsTrue(HelpText.StartsWith('#'), StrSubstNo(NotMarkdownErr, MessageType));
        LibraryAssert.IsTrue(HelpText.Contains(TypeName), StrSubstNo(NotSelfIdentifyingErr, MessageType));
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
        Argument: Record "Message Argument ori";
        BeginReq: JsonObject;
    begin
        BeginReq.Add('storageCode', MockCodeTok);
        BeginReq.Add('fileName', FileName);
        if FolderPath <> '' then
            BeginReq.Add('folderPath', FolderPath);
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Begin", BeginReq);
        LibraryAssert.AreEqual('Success', ReadText(Argument.GetResponseJson(), 'status'), 'Begin should succeed.');
        UploadId := ReadDataText(Argument, 'uploadId');
        Path := ReadDataText(Argument, 'path');
    end;

    local procedure AppendChunk(UploadId: Text; SequenceNo: Integer; ContentText: Text)
    var
        Argument: Record "Message Argument ori";
    begin
        AppendChunk(Argument, UploadId, SequenceNo, ContentText);
    end;

    local procedure AppendChunk(var Argument: Record "Message Argument ori"; UploadId: Text; SequenceNo: Integer; ContentText: Text)
    var
        Base64Convert: Codeunit "Base64 Convert";
        AppendReq: JsonObject;
    begin
        AppendReq.Add('uploadId', UploadId);
        AppendReq.Add('sequence', SequenceNo);
        AppendReq.Add('contentBase64', Base64Convert.ToBase64(ContentText));
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Append", AppendReq);
        LibraryAssert.AreEqual('Success', ReadText(Argument.GetResponseJson(), 'status'), 'Append should succeed.');
    end;

    local procedure CommitUpload(var Argument: Record "Message Argument ori"; UploadId: Text)
    var
        CommitReq: JsonObject;
    begin
        Clear(Argument);
        CommitReq.Add('uploadId', UploadId);
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.Upload.Commit", CommitReq);
    end;

    local procedure GetStoredText(Path: Text): Text
    var
        Argument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        TempBlob: Codeunit System.Utilities."Temp Blob";
        GetReq: JsonObject;
        ContentOutStream: OutStream;
        ContentInStream: InStream;
        Result: Text;
    begin
        GetReq.Add('storageCode', MockCodeTok);
        GetReq.Add('path', Path);
        ExecuteTypeWithRequest(Argument, Argument."Type"::"Storage.File.Get", GetReq);
        LibraryAssert.AreEqual('Success', ReadText(Argument.GetResponseJson(), 'status'), 'File get should succeed.');
        TempBlob.CreateOutStream(ContentOutStream);
        Base64Convert.FromBase64(ReadDataText(Argument, 'contentBase64'), ContentOutStream);
        TempBlob.CreateInStream(ContentInStream);
        ContentInStream.ReadText(Result);
        exit(Result);
    end;

    local procedure ExecuteTypeWithRequest(var Argument: Record "Message Argument ori"; MessageType: Enum "Message Type ori"; RequestJson: JsonObject)
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
        Argument.Init();
        Argument."Type" := MessageType;
        Argument.Insert(true);
        Argument.SetResponseJson(ResponseJson);
    end;

    local procedure MessageTypeName(MessageType: Enum "Message Type ori"): Text
    var
        Ordinals: List of [Integer];
        Names: List of [Text];
        Index: Integer;
    begin
        Ordinals := MessageType.Ordinals();
        Names := MessageType.Names();
        Index := Ordinals.IndexOf(MessageType.AsInteger());
        if Index = 0 then
            exit('');
        exit(Names.Get(Index));
    end;

    local procedure ReadData(ResponseJson: JsonObject) DataObject: JsonObject
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get('data', Token) then
            if Token.IsObject() then
                DataObject := Token.AsObject();
    end;

    local procedure ReadDataText(var Argument: Record "Message Argument ori"; PropertyName: Text): Text
    begin
        exit(ReadObjText(ReadData(Argument.GetResponseJson()), PropertyName));
    end;

    local procedure ReadDataInt(var Argument: Record "Message Argument ori"; PropertyName: Text): Integer
    var
        DataObject: JsonObject;
        Token: JsonToken;
    begin
        DataObject := ReadData(Argument.GetResponseJson());
        if DataObject.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsInteger());
        exit(0);
    end;

    local procedure ReadDataBool(var Argument: Record "Message Argument ori"; PropertyName: Text): Boolean
    var
        DataObject: JsonObject;
        Token: JsonToken;
    begin
        DataObject := ReadData(Argument.GetResponseJson());
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
}
