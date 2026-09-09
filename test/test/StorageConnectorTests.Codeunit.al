namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.Text;
using System.Utilities;

/// <summary>
/// Tests for the Bifrost Storage connector that run without a live storage account.
/// They cover message-type registration and metadata, per-type Markdown help, the
/// account-listing message type, and the full request/response pipeline driven through the
/// in-memory <c>Mock</c> backend (<c>Bifrost Storage Mock Impl</c> / <c>Bifrost Storage Mock State</c>).
/// </summary>
codeunit 96204 "Storage Connector Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        MockCodeTok: Label 'MOCK', Locked = true;

    [Test]
    procedure EveryStorageTypeHasMetadataAndHelp()
    var
        MessageType: Enum "Message Type ori";
        Ordinals: List of [Integer];
        Ordinal: Integer;
    begin
        // [SCENARIO] Every storage message type (72620-72634) exposes metadata and self-identifying help.
        Ordinals := MessageType.Ordinals();
        foreach Ordinal in Ordinals do
            if (Ordinal >= 72620) and (Ordinal <= 72634) then
                VerifyTypeMetadataAndHelp(Ordinal);
    end;

    [Test]
    procedure EveryMessageTypeHelpExplainsUsage()
    var
        MessageType: Enum "Message Type ori";
        Ordinals: List of [Integer];
        Ordinal: Integer;
    begin
        // [SCENARIO] Each callable storage type (72621-72634) documents enough for an AI agent to invoke it:
        // a JSON request example, the parameters it needs, and the response contract.
        Ordinals := MessageType.Ordinals();
        foreach Ordinal in Ordinals do
            if (Ordinal >= 72621) and (Ordinal <= 72634) then
                VerifyTypeHelpExplainsUsage(Ordinal);
    end;

    [Test]
    procedure HelpStorageGetReturnsOverviewMarkdown()
    var
        TempArgument: Record "Message Argument ori";
        MessageType: Enum "Message Type ori";
        ResponseJson: JsonObject;
        DataObject: JsonObject;
        Ordinals: List of [Integer];
        Markdown: Text;
        Ordinal: Integer;
        MissingFromCatalogErr: Label 'The overview should list message type %1 so an agent can discover it.', Comment = '%1 = message type';
    begin
        // [SCENARIO] Help.Storage.Get returns the uniform success envelope carrying the connector overview as Markdown.
        Initialize();

        // [WHEN] Help.Storage.Get executes (no request body required)
        ExecuteType(TempArgument, TempArgument."Type"::"Help.Storage.Get");

        // [THEN] The envelope is a success carrying markdown under data (same shape as every other message type)
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Help.Storage.Get should succeed.');
        DataObject := ReadData(ResponseJson);
        LibraryAssert.AreEqual('markdown', ReadObjText(DataObject, 'format'), 'The help format should be markdown.');
        Markdown := ReadObjText(DataObject, 'markdown');
        LibraryAssert.AreNotEqual('', Markdown, 'The overview markdown should not be empty.');

        // [THEN] The overview documents the routing model and the response envelope an agent must parse
        LibraryAssert.IsTrue(Markdown.Contains('Bifrost Storage Connector'), 'The overview should carry the connector title.');
        LibraryAssert.IsTrue(Markdown.Contains('storageCode'), 'The overview should explain storageCode routing.');
        LibraryAssert.IsTrue(Markdown.Contains('"status": "Success"'), 'The overview should document the success envelope.');

        // [THEN] The catalog lists every message type so an agent can compare them and pick one for a task
        Ordinals := MessageType.Ordinals();
        foreach Ordinal in Ordinals do
            if (Ordinal >= 72620) and (Ordinal <= 72634) then
                LibraryAssert.IsTrue(
                    Markdown.Contains(MessageTypeName(Enum::"Message Type ori".FromInteger(Ordinal))),
                    StrSubstNo(MissingFromCatalogErr, Enum::"Message Type ori".FromInteger(Ordinal)));

        // [THEN] It guides an automated caller to the discovery entry point (agent auto-navigation)
        LibraryAssert.IsTrue(Markdown.Contains('Getting started'), 'The overview should give an agent a starting flow.');
        LibraryAssert.IsTrue(Markdown.Contains('Storage.Account.List'), 'The overview should point to Storage.Account.List for code discovery.');
    end;

    [Test]
    procedure AccountListReturnsConfiguredCode()
    var
        TempArgument: Record "Message Argument ori";
        ResponseJson: JsonObject;
        DataObject: JsonObject;
        AccountsToken: JsonToken;
    begin
        // [GIVEN] One enabled mock storage connection
        Initialize();

        // [WHEN] Storage.Account.List executes
        ExecuteType(TempArgument, TempArgument."Type"::"Storage.Account.List");

        // [THEN] The envelope reports success and lists the configured code
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Account list should succeed.');
        DataObject := ReadData(ResponseJson);
        LibraryAssert.IsTrue(DataObject.Get('accounts', AccountsToken), 'The response should carry an accounts array.');
        LibraryAssert.IsTrue(AccountsToken.AsArray().Count() >= 1, 'At least the mock connection should be listed.');
    end;

    [Test]
    procedure FileCreateThenGetRoundtripsContent()
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DataObject: JsonObject;
        ExpectedBase64: Text;
    begin
        // [GIVEN] A base64 payload uploaded through Storage.File.Create
        Initialize();
        ExpectedBase64 := Base64Convert.ToBase64('Hello storage');
        RequestJson := PathRequest('docs/hello.txt');
        RequestJson.Add('contentBase64', ExpectedBase64);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Create", RequestJson);
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'File create should succeed.');

        // [WHEN] The same file is downloaded through Storage.File.Get
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Get", PathRequest('docs/hello.txt'));

        // [THEN] The returned content matches what was uploaded
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'File get should succeed.');
        DataObject := ReadData(ResponseJson);
        LibraryAssert.AreEqual(ExpectedBase64, ReadObjText(DataObject, 'contentBase64'), 'The downloaded content should match the upload.');
    end;

    [Test]
    procedure FileExistsReflectsCreateAndDelete()
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestJson: JsonObject;
    begin
        // [GIVEN] A file uploaded to the mock backend
        Initialize();
        RequestJson := PathRequest('a/b.txt');
        RequestJson.Add('contentBase64', Base64Convert.ToBase64('x'));
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Create", RequestJson);

        // [THEN] Storage.File.Exists reports it present
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Exists", PathRequest('a/b.txt'));
        LibraryAssert.IsTrue(ReadDataBool(TempArgument, 'exists'), 'The file should exist after create.');

        // [WHEN] It is deleted
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Delete", PathRequest('a/b.txt'));
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'File delete should succeed.');

        // [THEN] Storage.File.Exists reports it gone
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Exists", PathRequest('a/b.txt'));
        LibraryAssert.IsFalse(ReadDataBool(TempArgument, 'exists'), 'The file should be gone after delete.');
    end;

    [Test]
    procedure FileDelete_LinkedAttachment_ReturnsError()
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] A storage file linked to a Business Central attachment cannot be deleted directly.
        Initialize();
        RequestJson := PathRequest('linked/doc.txt');
        RequestJson.Add('contentBase64', Base64Convert.ToBase64('linked content'));
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Create", RequestJson);
        CreateLinkedIncomingAttachment('linked/doc.txt', 'doc.txt');

        // [WHEN] The linked file is deleted through Storage.File.Delete
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Delete", PathRequest('linked/doc.txt'));

        // [THEN] The operation is rejected before storage is changed
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'Linked file delete should fail.');
        LibraryAssert.IsTrue(ReadText(TempArgument.GetResponseJson(), 'error').Contains('cannot be deleted'), 'The error should explain that the file is linked.');
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Exists", PathRequest('linked/doc.txt'));
        LibraryAssert.IsTrue(ReadDataBool(TempArgument, 'exists'), 'The linked file should still exist after the blocked delete.');
    end;

    [Test]
    procedure DirectoryDelete_ContainsLinkedAttachment_ReturnsError()
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] A directory containing a linked Business Central attachment file cannot be deleted directly.
        Initialize();
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Directory.Create", PathRequest('linked'));
        RequestJson := PathRequest('linked/doc.txt');
        RequestJson.Add('contentBase64', Base64Convert.ToBase64('linked content'));
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Create", RequestJson);
        CreateLinkedIncomingAttachment('linked/doc.txt', 'doc.txt');

        // [WHEN] The parent directory is deleted through Storage.Directory.Delete
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Directory.Delete", PathRequest('linked'));

        // [THEN] The operation is rejected before storage is changed
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'Linked directory delete should fail.');
        LibraryAssert.IsTrue(ReadText(TempArgument.GetResponseJson(), 'error').Contains('cannot be deleted'), 'The error should explain that the directory contains linked files.');
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Directory.Exists", PathRequest('linked'));
        LibraryAssert.IsTrue(ReadDataBool(TempArgument, 'exists'), 'The linked directory should still exist after the blocked delete.');
    end;

    [Test]
    procedure FileMove_LinkedAttachment_UpdatesLinkPath()
    var
        Link: Record "Storage Attachment Link ori";
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestJson: JsonObject;
        MoveJson: JsonObject;
    begin
        // [SCENARIO] Moving a linked storage file updates the Business Central attachment link to the new path.
        Initialize();
        RequestJson := PathRequest('linked/doc.txt');
        RequestJson.Add('contentBase64', Base64Convert.ToBase64('linked content'));
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Create", RequestJson);
        CreateLinkedIncomingAttachment('linked/doc.txt', 'doc.txt');

        // [WHEN] The linked file is moved through Storage.File.Move
        MoveJson.Add('storageCode', MockCodeTok);
        MoveJson.Add('sourcePath', 'linked/doc.txt');
        MoveJson.Add('targetPath', 'linked/archive/doc.txt');
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Move", MoveJson);

        // [THEN] The move succeeds and the link row follows the file
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Linked file move should succeed.');
        Link.SetRange("Storage Code", MockCodeTok);
        Link.SetRange("Storage Path", 'linked/archive/doc.txt');
        LibraryAssert.IsTrue(Link.FindFirst(), 'The link should point to the moved file path.');
        Link.SetRange("Storage Path", 'linked/doc.txt');
#pragma warning disable AA0175
        LibraryAssert.IsFalse(Link.FindFirst(), 'No link should remain on the old file path.');
#pragma warning restore AA0175
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Exists", PathRequest('linked/archive/doc.txt'));
        LibraryAssert.IsTrue(ReadDataBool(TempArgument, 'exists'), 'The moved file should exist at the target path.');
    end;

    [Test]
    procedure CreateLinked_DuplicatePath_ReturnsError()
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] Linking two attachments to the same storage path is blocked.
        Initialize();
        RequestJson := PathRequest('dup-link/doc.txt');
        RequestJson.Add('contentBase64', Base64Convert.ToBase64('dup content'));
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Create", RequestJson);
        CreateLinkedIncomingAttachment('dup-link/doc.txt', 'doc.txt');

        // [WHEN] A second attachment is linked to the same path
        // [THEN] The call fails with an already-linked error
        Clear(RequestJson);
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('path', 'dup-link/doc.txt');
        RequestJson.Add('fileName', 'doc2.txt');
        asserterror ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateLinked", RequestJson);
        LibraryAssert.ExpectedError('already linked');
    end;

    [Test]
    procedure FileListReturnsEntriesUnderPath()
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestJson: JsonObject;
        DataObject: JsonObject;
        EntriesToken: JsonToken;
    begin
        // [GIVEN] Two files in the same directory
        Initialize();
        RequestJson := PathRequest('dir/one.txt');
        RequestJson.Add('contentBase64', Base64Convert.ToBase64('1'));
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Create", RequestJson);
        Clear(RequestJson);
        RequestJson := PathRequest('dir/two.txt');
        RequestJson.Add('contentBase64', Base64Convert.ToBase64('2'));
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Create", RequestJson);

        // [WHEN] The directory is listed
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.List", PathRequest('dir'));

        // [THEN] Both files are returned
        DataObject := ReadData(TempArgument.GetResponseJson());
        LibraryAssert.IsTrue(DataObject.Get('entries', EntriesToken), 'The response should carry an entries array.');
        LibraryAssert.AreEqual(2, EntriesToken.AsArray().Count(), 'Both files should be listed.');
    end;

    [Test]
    procedure DirectoryCreateExistsDelete()
    var
        TempArgument: Record "Message Argument ori";
    begin
        // [GIVEN] A created directory
        Initialize();
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Directory.Create", PathRequest('reports'));

        // [THEN] It is reported present, then absent after deletion
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Directory.Exists", PathRequest('reports'));
        LibraryAssert.IsTrue(ReadDataBool(TempArgument, 'exists'), 'The directory should exist after create.');

        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Directory.Delete", PathRequest('reports'));
        Clear(TempArgument);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Directory.Exists", PathRequest('reports'));
        LibraryAssert.IsFalse(ReadDataBool(TempArgument, 'exists'), 'The directory should be gone after delete.');
    end;

    [Test]
    procedure UnknownStorageCodeReturnsError()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [GIVEN] A request naming a storage code that is not configured
        Initialize();
        RequestJson.Add('storageCode', 'NOPE');
        RequestJson.Add('path', 'x.txt');

        // [WHEN] Storage.File.Exists executes
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Exists", RequestJson);

        // [THEN] The envelope reports an error
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'An unknown storage code should error.');
    end;

    [Test]
    procedure DisabledConnectionIsRejected()
    var
        StorageSetup: Record "Storage Setup ori";
        TempArgument: Record "Message Argument ori";
    begin
        // [GIVEN] The mock connection is disabled
        Initialize();
        StorageSetup.Get(MockCodeTok);
        StorageSetup.Enabled := false;
        StorageSetup.Modify();

        // [WHEN] Storage.File.Exists executes against it
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Exists", PathRequest('x.txt'));

        // [THEN] The envelope reports an error
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'A disabled connection should be rejected.');
    end;

    [Test]
    procedure MissingPathReturnsError()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [GIVEN] A request that omits the required path
        Initialize();
        RequestJson.Add('storageCode', MockCodeTok);

        // [WHEN] Storage.File.Get executes
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Get", RequestJson);

        // [THEN] The envelope reports an error
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'A missing path should error.');
    end;

    [Test]
    procedure RelativePathSegmentIsRejected()
    var
        TempArgument: Record "Message Argument ori";
    begin
        // [SCENARIO] The base path is a connection's only confinement boundary, so a caller must
        // not be able to walk out of it with a relative segment.
        // [GIVEN] A request whose path climbs above the base path
        Initialize();

        // [WHEN] Storage.File.Get executes
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Get", PathRequest('../../secret.txt'));

        // [THEN] The envelope reports an error instead of reaching the connector
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'A path with a ".." segment should be rejected.');
    end;

    [Test]
    procedure RelativePathWithBackslashesIsRejected()
    var
        TempArgument: Record "Message Argument ori";
    begin
        // [GIVEN] A request that hides the relative segment behind Windows separators
        Initialize();

        // [WHEN] Storage.Directory.Create executes
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Directory.Create", PathRequest('reports\..\..\etc'));

        // [THEN] The envelope reports an error - both slash directions are checked
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'A backslash path with a ".." segment should be rejected.');
    end;

    [Test]
    procedure CurrentDirectorySegmentIsRejected()
    var
        TempArgument: Record "Message Argument ori";
    begin
        // [GIVEN] A request carrying a "." segment
        Initialize();

        // [WHEN] Storage.File.Exists executes
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Exists", PathRequest('docs/./hello.txt'));

        // [THEN] The envelope reports an error
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'A path with a "." segment should be rejected.');
    end;

    [Test]
    procedure DotsInsideAFileNameAreAccepted()
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] Only whole path segments are rejected - dots inside a name are legitimate.
        // [GIVEN] A file whose name contains dots
        Initialize();
        RequestJson := PathRequest('docs/my..archive.v1.txt');
        RequestJson.Add('contentBase64', Base64Convert.ToBase64('ok'));

        // [WHEN] Storage.File.Create executes
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Create", RequestJson);

        // [THEN] The file is created
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Dots inside a file name should be allowed.');
    end;

    [Test]
    procedure GetMissingFileReturnsError()
    var
        TempArgument: Record "Message Argument ori";
    begin
        // [GIVEN] An empty backend
        Initialize();

        // [WHEN] Storage.File.Get targets a file that does not exist
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Get", PathRequest('missing.txt'));

        // [THEN] The backend error is surfaced in the envelope
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'Reading a missing file should error.');
    end;

    [Test]
    procedure DocumentAttachmentOffloadRestoreRoundtrip()
    var
        DocumentAttachment: Record "Document Attachment";
        Customer: Record Customer;
        TempArgument: Record "Message Argument ori";
        TempBlob: Codeunit "Temp Blob";
        RecRef: RecordRef;
        OffloadReq: JsonObject;
        RestoreReq: JsonObject;
        DataObject: JsonObject;
        OutStr: OutStream;
        InStr: InStream;
        SystemIdGuid: Guid;
        ExpectedContent: Text;
        ReadBack: Text;
    begin
        // [GIVEN] A mock storage connection and a Document Attachment holding a small file
        Initialize();
        Customer.Init();
        Customer."No." := 'BIFTS-ATT-CUST';
        if not Customer.Insert() then
            Customer.Get(Customer."No.");
        ExpectedContent := 'Hello attachment payload';
        TempBlob.CreateOutStream(OutStr);
        OutStr.WriteText(ExpectedContent);
        RecRef.GetTable(Customer);
        DocumentAttachment.SaveAttachment(RecRef, 'doc.txt', TempBlob);
        DocumentAttachment.SetRange("Table ID", Database::Customer);
        DocumentAttachment.SetRange("No.", Customer."No.");
        DocumentAttachment.FindLast();
        SystemIdGuid := DocumentAttachment.SystemId;

        // [WHEN] Storage.Attachment.Offload moves it to the mock connection, into a chosen folder
        OffloadReq.Add('target', 'DocumentAttachment');
        OffloadReq.Add('systemId', Format(SystemIdGuid, 0, 4));
        OffloadReq.Add('storageCode', MockCodeTok);
        OffloadReq.Add('folderPath', 'attachments/customer');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.Offload", OffloadReq);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Offload should succeed.');

        // [THEN] The file is stored under the requested folder, with the file name appended
        DataObject := ReadData(TempArgument.GetResponseJson());
        LibraryAssert.AreEqual('attachments/customer/doc.txt', ReadObjText(DataObject, 'path'), 'Offload should honor the requested folderPath.');

        // [THEN] The local media is cleared from the database
        DocumentAttachment.GetBySystemId(SystemIdGuid);
        LibraryAssert.IsFalse(DocumentAttachment."Document Reference ID".HasValue(), 'Local media should be cleared after offload.');

        // [THEN] The content is still served transparently through the standard accessor
        Clear(TempBlob);
        DocumentAttachment.GetAsTempBlob(TempBlob);
        TempBlob.CreateInStream(InStr);
        InStr.ReadText(ReadBack);
        LibraryAssert.AreEqual(ExpectedContent, ReadBack, 'Offloaded content should be served transparently from storage.');

        // [WHEN] Storage.Attachment.Restore brings it back
        Clear(TempArgument);
        RestoreReq.Add('target', 'DocumentAttachment');
        RestoreReq.Add('systemId', Format(SystemIdGuid, 0, 4));
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.Restore", RestoreReq);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Restore should succeed.');

        // [THEN] The media is back in the database
        DocumentAttachment.GetBySystemId(SystemIdGuid);
        LibraryAssert.IsTrue(DocumentAttachment."Document Reference ID".HasValue(), 'Media should be restored to the database.');
    end;

    [Test]
    procedure OffloadPreservesDocumentAttachmentUiBehaviour()
    var
        DocumentAttachment: Record "Document Attachment";
        Customer: Record Customer;
        TempArgument: Record "Message Argument ori";
        SeedBlob: Codeunit "Temp Blob";
        ExportBlob: Codeunit "Temp Blob";
        RecRef: RecordRef;
        OffloadReq: JsonObject;
        SeedOut: OutStream;
        ExportOut: OutStream;
        ContentIn: InStream;
        SystemIdGuid: Guid;
        Expected: Text;
        ReadBack: Text;
        HadContent: Boolean;
        ViewerSupported: Boolean;
    begin
        // [SCENARIO] After offloading a Document Attachment, the UI behaves exactly as before:
        // it still reports content (View/Download stay enabled) and the accessors return the file.
        Initialize();
        Customer.Init();
        Customer."No." := 'BIFTS-UI-CUST';
        if not Customer.Insert() then
            Customer.Get(Customer."No.");
        Expected := 'UI document attachment content';
        SeedBlob.CreateOutStream(SeedOut);
        SeedOut.WriteText(Expected);
        RecRef.GetTable(Customer);
        DocumentAttachment.SaveAttachment(RecRef, 'invoice.pdf', SeedBlob);
        DocumentAttachment.SetRange("Table ID", Database::Customer);
        DocumentAttachment.SetRange("No.", Customer."No.");
        DocumentAttachment.FindLast();
        SystemIdGuid := DocumentAttachment.SystemId;

        // [GIVEN] The UI signals the pages rely on, captured before offload
        HadContent := DocumentAttachment.HasContent();
        ViewerSupported := DocumentAttachment.SupportedByFileViewer();
        LibraryAssert.IsTrue(HadContent, 'Sanity: the attachment should report content before offload.');

        // [WHEN] The file is offloaded
        OffloadReq.Add('target', 'DocumentAttachment');
        OffloadReq.Add('systemId', Format(SystemIdGuid, 0, 4));
        OffloadReq.Add('storageCode', MockCodeTok);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.Offload", OffloadReq);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Offload should succeed.');
        DocumentAttachment.GetBySystemId(SystemIdGuid);

        // [THEN] The page gating is unchanged: still reports content and the same viewer support
        LibraryAssert.AreEqual(HadContent, DocumentAttachment.HasContent(), 'HasContent must be unchanged so View/Download stay enabled.');
        LibraryAssert.AreEqual(ViewerSupported, DocumentAttachment.SupportedByFileViewer(), 'File-viewer support must be unchanged.');

        // [THEN] The accessors the UI uses to View/Download still return the original content
        DocumentAttachment.GetAsTempBlob(ExportBlob);
        ExportBlob.CreateInStream(ContentIn);
        ContentIn.ReadText(ReadBack);
        LibraryAssert.AreEqual(Expected, ReadBack, 'GetAsTempBlob (View/Download) must return the original content.');

        Clear(ExportBlob);
        ExportBlob.CreateOutStream(ExportOut);
        DocumentAttachment.ExportToStream(ExportOut);
        ExportBlob.CreateInStream(ContentIn);
        ContentIn.ReadText(ReadBack);
        LibraryAssert.AreEqual(Expected, ReadBack, 'ExportToStream must return the original content.');
    end;

    [Test]
    procedure OffloadPreservesIncomingDocumentUiBehaviour()
    var
        IncomingDocument: Record "Incoming Document";
        Attachment: Record "Incoming Document Attachment";
        TempArgument: Record "Message Argument ori";
        SeedBlob: Codeunit "Temp Blob";
        ContentBlob: Codeunit "Temp Blob";
        OffloadReq: JsonObject;
        SeedOut: OutStream;
        SeedIn: InStream;
        ContentIn: InStream;
        SystemIdGuid: Guid;
        Expected: Text;
        ReadBack: Text;
    begin
        // [SCENARIO] After offloading an Incoming Document attachment, the standard download path
        // (GetContent, used by the Export action) still reports and returns the file unchanged.
        Initialize();
        Expected := 'UI incoming document content';
        SeedBlob.CreateOutStream(SeedOut);
        SeedOut.WriteText(Expected);
        SeedBlob.CreateInStream(SeedIn);
        IncomingDocument.Init();
        IncomingDocument.CreateIncomingDocument('claude-ui', 'claude-ui.pdf');
        IncomingDocument.AddAttachmentFromStream(Attachment, 'claude-ui.pdf', 'pdf', SeedIn);
        SystemIdGuid := Attachment.SystemId;

        // [GIVEN] The download path reports content before offload
        LibraryAssert.IsTrue(Attachment.GetContent(ContentBlob), 'Sanity: content present before offload.');

        // [WHEN] The file is offloaded
        OffloadReq.Add('target', 'IncomingDocument');
        OffloadReq.Add('systemId', Format(SystemIdGuid, 0, 4));
        OffloadReq.Add('storageCode', MockCodeTok);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.Offload", OffloadReq);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Offload should succeed.');
        Attachment.GetBySystemId(SystemIdGuid);

        // [THEN] GetContent still reports content (Download stays enabled) and returns the original bytes
        Clear(ContentBlob);
        LibraryAssert.IsTrue(Attachment.GetContent(ContentBlob), 'GetContent must still report content after offload.');
        ContentBlob.CreateInStream(ContentIn);
        ContentIn.ReadText(ReadBack);
        LibraryAssert.AreEqual(Expected, ReadBack, 'GetContent must return the original content transparently.');
    end;

    local procedure Initialize()
    var
        StorageSetup: Record "Storage Setup ori";
        AttachmentLink: Record "Storage Attachment Link ori";
        MockState: Codeunit "Storage Mock State";
    begin
        MockState.Reset();
        AttachmentLink.DeleteAll();
        StorageSetup.DeleteAll();
        StorageSetup.Init();
        StorageSetup."Code" := MockCodeTok;
        StorageSetup.Description := 'Mock storage connection';
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::Mock;
        StorageSetup.Enabled := true;
        StorageSetup.Insert();
    end;

    local procedure PathRequest(Path: Text) RequestJson: JsonObject
    begin
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('path', Path);
    end;

    local procedure CreateLinkedIncomingAttachment(Path: Text; FileName: Text)
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('path', Path);
        RequestJson.Add('fileName', FileName);
        RequestJson.Add('description', 'X linked attachment');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateLinked", RequestJson);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'The linked incoming attachment should be created.');
    end;

    local procedure VerifyTypeMetadataAndHelp(Ordinal: Integer)
    var
        TempArgument: Record "Message Argument ori";
        MessageType: Enum "Message Type ori";
        MsgInterface: Interface "Msg Interface ori";
        HelpText: Text;
        TypeName: Text;
        WrongDirectionErr: Label 'Type %1 has the wrong message direction.', Comment = '%1 = message type';
        NoDescriptionErr: Label 'Type %1 should have a description.', Comment = '%1 = message type';
        NoHelpErr: Label 'Type %1 should produce help markdown.', Comment = '%1 = message type';
        NotMarkdownErr: Label 'Type %1 help should start with a Markdown heading.', Comment = '%1 = message type';
        NotSelfIdentifyingErr: Label 'Type %1 help should name the message type so an agent can map the document to the tool.', Comment = '%1 = message type';
    begin
        MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
        TypeName := MessageTypeName(MessageType);
        TempArgument.Init();
        TempArgument."Type" := MessageType;
        TempArgument.Insert(true);
        MsgInterface := TempArgument.GetMessageTypeInterface();

        // Attachment offload/restore write to the database, so they are inbound; everything else is outbound.
        if Ordinal >= 72633 then
            LibraryAssert.AreEqual(
                Enum::"Msg Direction ori"::Inbound,
                MsgInterface.GetMessageDirection(),
                StrSubstNo(WrongDirectionErr, MessageType))
        else
            LibraryAssert.AreEqual(
                Enum::"Msg Direction ori"::Outbound,
                MsgInterface.GetMessageDirection(),
                StrSubstNo(WrongDirectionErr, MessageType));
        LibraryAssert.AreNotEqual('', MsgInterface.GetDescription(), StrSubstNo(NoDescriptionErr, MessageType));

        MsgInterface.GetMessageHelpAsMarkdownDocument(TempArgument);
        HelpText := TempArgument.GetResponseText();
        LibraryAssert.AreNotEqual('', HelpText, StrSubstNo(NoHelpErr, MessageType));
        LibraryAssert.IsTrue(HelpText.StartsWith('#'), StrSubstNo(NotMarkdownErr, MessageType));
        LibraryAssert.IsTrue(HelpText.Contains(TypeName), StrSubstNo(NotSelfIdentifyingErr, MessageType));
    end;

    local procedure VerifyTypeHelpExplainsUsage(Ordinal: Integer)
    var
        TempArgument: Record "Message Argument ori";
        MessageType: Enum "Message Type ori";
        MsgInterface: Interface "Msg Interface ori";
        HelpText: Text;
        NoExampleErr: Label 'Type %1 help should include a JSON request example so an agent can shape the call.', Comment = '%1 = message type';
        NoResponseErr: Label 'Type %1 help should document the response contract.', Comment = '%1 = message type';
        NoParamsErr: Label 'Type %1 help should document its parameters, including storageCode.', Comment = '%1 = message type';
    begin
        MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
        TempArgument.Init();
        TempArgument."Type" := MessageType;
        TempArgument.Insert(true);
        MsgInterface := TempArgument.GetMessageTypeInterface();
        MsgInterface.GetMessageHelpAsMarkdownDocument(TempArgument);
        HelpText := TempArgument.GetResponseText();

        // [THEN] An agent can see how to call it and what it returns
        LibraryAssert.IsTrue(HelpText.Contains('```json'), StrSubstNo(NoExampleErr, MessageType));
        LibraryAssert.IsTrue(HelpText.Contains('## Response'), StrSubstNo(NoResponseErr, MessageType));

        // [THEN] All parameterised operations (file, directory, attachment) document their inputs
        if Ordinal >= 72622 then
            LibraryAssert.IsTrue(HelpText.Contains('## Parameters'), StrSubstNo(NoParamsErr, MessageType));

        // [THEN] Operations that target a connection by code document storageCode.
        // Storage.Attachment.Restore (72634) is excluded: it derives the connection from the offload record.
        if (Ordinal >= 72622) and (Ordinal <> 72634) then
            LibraryAssert.IsTrue(HelpText.Contains('storageCode'), StrSubstNo(NoParamsErr, MessageType));
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

    local procedure ExecuteType(var TempArgument: Record "Message Argument ori"; MessageType: Enum "Message Type ori")
    var
        RequestJson: JsonObject;
    begin
        ExecuteTypeWithRequest(TempArgument, MessageType, RequestJson);
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
}
