namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.Text;
using System.Utilities;

/// <summary>Story 75 regression tests exercise public messages and read back protected content and state.</summary>
codeunit 96225 "Storage Integrity 75 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Function;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        MockCodeTok: Label 'X75', Locked = true;

    /// <summary>Outer slash spelling cannot bypass linked file or parent-directory deletion guards.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_SlashDeletes_PreserveLinkedContent()
    var
        RequestJson: JsonObject;
        Response: JsonObject;
        AttachmentId: Guid;
    begin
        // Story #75, AC01 | Time: no date dependence | Risk: connector normalization must be independent.
        Initialize();
        // [GIVEN] A real incoming attachment backed by provider-normalized content.
        AttachmentId := CreateLinked('Xdir/Xfile.txt');
        // [WHEN] Alternate spellings target the same file and containing directory.
        Response := Execute(Enum::"Message Type ori"::"Storage.File.Delete", PathRequest('/Xdir/Xfile.txt/'));
        AssertRefusal(Response, 'PreconditionFailed');
        Response := Execute(Enum::"Message Type ori"::"Storage.Directory.Delete", PathRequest('/Xdir/'));
        AssertRefusal(Response, 'PreconditionFailed');
        RequestJson := PathRequest('/');
        Response := Execute(Enum::"Message Type ori"::"Storage.Directory.Delete", RequestJson);
        AssertRefusal(Response, 'PreconditionFailed');
        // [THEN] The original attachment still serves the original bytes and its link is unchanged.
        AssertLinkedContent(AttachmentId, 'Xdir/Xfile.txt');
    end;

    /// <summary>Canonical comparisons also protect existing noncanonical stored links.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_LegacySlashLink_RejectsCanonicalDelete()
    var
        Link: Record "Storage Attachment Link ori";
        Response: JsonObject;
        AttachmentId: Guid;
    begin
        // Story #75, AC01 | Time: no date dependence | Risk: legacy link spelling.
        Initialize();
        // [GIVEN] A legacy link whose spelling includes outer slashes.
        AttachmentId := CreateLinked('Xdir/Xfile.txt');
        Link.Get(Database::"Incoming Document Attachment", AttachmentId);
        Link."Storage Path" := '/Xdir/Xfile.txt/';
        Link.Modify();
        // [WHEN] A caller addresses its canonical provider key.
        Response := Execute(Enum::"Message Type ori"::"Storage.File.Delete", PathRequest('Xdir/Xfile.txt'));
        // [THEN] Both persisted spelling and served content survive rejection.
        AssertRefusal(Response, 'PreconditionFailed');
        AssertLinkedContent(AttachmentId, '/Xdir/Xfile.txt/');
    end;

    /// <summary>Raw create cannot overwrite an attachment through a slash alias.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC02_CreateLinkedTarget_PreservesBytesAndLink()
    var
        RequestJson: JsonObject;
        Response: JsonObject;
        AttachmentId: Guid;
    begin
        // Story #75, AC02 | Time: no date dependence | Risk: provider overwrites existing keys.
        Initialize();
        // [GIVEN] Linked original content.
        AttachmentId := CreateLinked('Xdir/Xfile.txt');
        RequestJson := ContentRequest('/Xdir/Xfile.txt/', 'replacement');
        // [WHEN] A raw create addresses it.
        Response := Execute(Enum::"Message Type ori"::"Storage.File.Create", RequestJson);
        // [THEN] The response is actionable and the attachment remains intact.
        AssertRefusal(Response, 'PreconditionFailed');
        AssertLinkedContent(AttachmentId, 'Xdir/Xfile.txt');
    end;

    /// <summary>Copy and move reject linked destinations before changing either file.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC02_TransfersToLinkedTarget_PreserveBothFiles()
    var
        Response: JsonObject;
        AttachmentId: Guid;
    begin
        // Story #75, AC02 | Time: no date dependence | Risk: overwrite plus source deletion.
        Initialize();
        // [GIVEN] An unlinked source and a linked destination.
        AttachmentId := CreateLinked('Xdir/Xfile.txt');
        AssertSuccess(Execute(Enum::"Message Type ori"::"Storage.File.Create", ContentRequest('Xsource.txt', 'source')));
        // [WHEN] Copy and move use a destination alias.
        Response := Execute(Enum::"Message Type ori"::"Storage.File.Copy", TransferRequest('Xsource.txt', '/Xdir/Xfile.txt/'));
        AssertRefusal(Response, 'PreconditionFailed');
        Response := Execute(Enum::"Message Type ori"::"Storage.File.Move", TransferRequest('Xsource.txt', '/Xdir/Xfile.txt/'));
        AssertRefusal(Response, 'PreconditionFailed');
        // [THEN] Source and target bytes, link and native attachment content are unchanged.
        LibraryAssert.AreEqual('source', StoredText('Xsource.txt'), 'Rejected transfers must preserve the source.');
        AssertLinkedContent(AttachmentId, 'Xdir/Xfile.txt');
    end;

    /// <summary>Upload commit rechecks links created after Begin and preserves the reusable session.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC02_UploadTargetBecomesLinked_PreservesSession()
    var
        Session: Record "Storage Upload Session ori";
        Chunk: Record "Storage Upload Chunk ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestJson: JsonObject;
        Response: JsonObject;
        AttachmentId: Guid;
        UploadId: Guid;
    begin
        // Story #75, AC02 | Time: session timestamps do not affect the oracle | Risk: begin/commit race.
        Initialize();
        // [GIVEN] An upload started before its destination became an attachment.
        RequestJson := PathRequest('/Xdir/Xfile.txt/');
        RequestJson.Add('fileName', 'Xfile.txt');
        Response := Execute(Enum::"Message Type ori"::"Storage.Upload.Begin", RequestJson);
        AssertSuccess(Response);
        Evaluate(UploadId, DataText(Response, 'uploadId'));
        Clear(RequestJson);
        RequestJson.Add('uploadId', Format(UploadId, 0, 4));
        RequestJson.Add('sequence', 1);
        RequestJson.Add('contentBase64', Base64Convert.ToBase64('replacement'));
        AssertSuccess(Execute(Enum::"Message Type ori"::"Storage.Upload.Append", RequestJson));
        AttachmentId := CreateLinked('Xdir/Xfile.txt');
        // [WHEN] Commit would overwrite the now-linked target.
        Clear(RequestJson);
        RequestJson.Add('uploadId', Format(UploadId, 0, 4));
        Response := Execute(Enum::"Message Type ori"::"Storage.Upload.Commit", RequestJson);
        // [THEN] The original file/link and all session/chunk state remain reusable.
        AssertRefusal(Response, 'PreconditionFailed');
        AssertLinkedContent(AttachmentId, 'Xdir/Xfile.txt');
        Session.Get(UploadId);
        LibraryAssert.AreEqual(Session.Status::Open, Session.Status, 'The rejected session must remain open.');
        LibraryAssert.AreEqual(1, Session."Chunk Count", 'The chunk count must remain unchanged.');
        LibraryAssert.AreEqual(11, Session."Received Size", 'The received size must remain unchanged.');
        LibraryAssert.IsTrue(Chunk.Get(UploadId, 1), 'The chunk must remain available for retry.');
    end;

    /// <summary>A legal slash-spelled source move updates only the matching link and preserves content.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_SlashSourceMove_UpdatesOnlyMatchingLink()
    var
        Response: JsonObject;
        AttachmentId: Guid;
        OtherAttachmentId: Guid;
    begin
        // Story #75, AC01 | Time: no date dependence | Risk: canonical scan must not update unrelated links.
        Initialize();
        // [GIVEN] Two real attachments under the same storage code.
        AttachmentId := CreateLinked('Xdir/Xfile.txt');
        OtherAttachmentId := CreateLinked('Xdir/Xother.txt');
        // [WHEN] Only the first file moves.
        Response := Execute(Enum::"Message Type ori"::"Storage.File.Move", TransferRequest('/Xdir/Xfile.txt/', '/Xarchive/Xfile.txt/'));
        // [THEN] The matching link follows the canonical target; the other link is untouched.
        AssertSuccess(Response);
        AssertLinkedContent(AttachmentId, 'Xarchive/Xfile.txt');
        AssertLinkedContent(OtherAttachmentId, 'Xdir/Xother.txt');
    end;

    /// <summary>Stored path boundaries are explicit, and the overlimit request writes nothing.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC03_Path2047To2049_RejectsOnlyOverFieldLimit()
    var
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
        Path: Text;
        PathLength: Integer;
    begin
        // Story #75, AC03 | Time: no date dependence | Risk: mock field capacity is not provider certification.
        Initialize();
        // [GIVEN] Full paths at, below and above the storage field limit.
        for PathLength := 2047 to 2049 do begin
            Path := LongPath(PathLength);
            // [WHEN] A complete address is used for a raw file create.
            Response := Execute(Enum::"Message Type ori"::"Storage.File.Create", ContentRequest(Path, 'boundary'));
            // [THEN] Accepted bytes use the exact full key; rejected input creates no file.
            if PathLength <= 2048 then begin
                AssertSuccess(Response);
                LibraryAssert.AreEqual('boundary', StoredText(Path), 'The accepted address must not be truncated.');
            end else begin
                AssertRefusal(Response, 'LimitExceeded');
                LibraryAssert.IsFalse(MockState.HasFile(Path), 'An overlimit path must not be written.');
            end;
        end;
    end;

    /// <summary>Base path length contributes to the full address limit.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC03_BasePlusPathTooLong_RejectsBeforeWrite()
    var
        StorageSetup: Record "Storage Setup ori";
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
    begin
        // Story #75, AC03 | Time: no date dependence | Risk: relative address alone fits.
        Initialize();
        // [GIVEN] A nonempty base with a individually valid relative path.
        StorageSetup.Get(MockCodeTok);
        StorageSetup."Base Path" := 'Xbase';
        StorageSetup.Modify();
        // [WHEN] Their combination exceeds the stored address capacity.
        Response := Execute(Enum::"Message Type ori"::"Storage.File.Create", ContentRequest(LongPath(2048), 'boundary'));
        // [THEN] No remote file was created.
        AssertRefusal(Response, 'LimitExceeded');
        LibraryAssert.AreEqual(0, MockState.FilePaths().Count(), 'Full-address validation must precede writes.');
    end;

    /// <summary>Upload filename limits reject complete overlength names instead of truncating them.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC03_Name249To251_RejectsBeforeSessionInsert()
    var
        Session: Record "Storage Upload Session ori";
        RequestJson: JsonObject;
        Response: JsonObject;
        UploadId: Guid;
        FileName: Text;
        NameLength: Integer;
        BeforeCount: Integer;
    begin
        // Story #75, AC03 | Time: no date dependence | Risk: database Text[250] assignment.
        Initialize();
        for NameLength := 249 to 251 do begin
            // [GIVEN] The complete filename, including extension.
            FileName := PadStr('X', NameLength - 4, 'a') + '.txt';
            Clear(RequestJson);
            RequestJson.Add('fileName', FileName);
            BeforeCount := Session.Count();
            // [WHEN] An attachment-only upload begins.
            Response := Execute(Enum::"Message Type ori"::"Storage.Upload.Begin", RequestJson);
            // [THEN] The accepted name is exact and refusal inserts no session.
            if NameLength <= 250 then begin
                AssertSuccess(Response);
                Evaluate(UploadId, DataText(Response, 'uploadId'));
                Session.Get(UploadId);
                LibraryAssert.AreEqual(FileName, Session."File Name", 'The name must not be truncated.');
            end else begin
                AssertRefusal(Response, 'LimitExceeded');
                LibraryAssert.AreEqual(BeforeCount, Session.Count(), 'An invalid name must not create a session.');
            end;
        end;
    end;

    /// <summary>Invalid traversal and root file paths fail without connector writes.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC04_TraversalAndFileRoot_RejectWithoutWrites()
    var
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
    begin
        // Story #75, AC04 | Time: no date dependence | Risk: root is legal only for directories.
        Initialize();
        // [GIVEN/WHEN] Attempts to escape the base or use the root as a file.
        Response := Execute(Enum::"Message Type ori"::"Storage.File.Create", ContentRequest('Xdir/../Xfile.txt', 'bad'));
        AssertRefusal(Response, 'InvalidParameter');
        Response := Execute(Enum::"Message Type ori"::"Storage.File.Create", ContentRequest('/', 'bad'));
        AssertRefusal(Response, 'InvalidParameter');
        // [THEN] No connector file was written.
        LibraryAssert.AreEqual(0, MockState.FilePaths().Count(), 'Unsafe file paths must not reach the connector.');
    end;

    /// <summary>A generated overlength offload path is refused while the only content remains local.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC03_GeneratedOffloadTooLong_PreservesLocalBlob()
    var
        Attachment: Record "Incoming Document Attachment";
        Link: Record "Storage Attachment Link ori";
        MockState: Codeunit "Storage Mock State";
        TempBlob: Codeunit "Temp Blob";
        RequestJson: JsonObject;
        Response: JsonObject;
        AttachmentId: Guid;
        ContentIn: InStream;
        ContentText: Text;
    begin
        // Story #75, AC03 | Time: no date dependence | Risk: generated path exceeds a valid folder.
        Initialize();
        // [GIVEN] A real attachment restored to local content before a second offload.
        AttachmentId := CreateLinked('Xdir/Xfile.txt');
        RequestJson.Add('target', 'IncomingDocument');
        RequestJson.Add('systemId', Format(AttachmentId, 0, 4));
        AssertSuccess(Execute(Enum::"Message Type ori"::"Storage.Attachment.Restore", RequestJson));
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('folderPath', LongPath(2048));
        // [WHEN] A valid-size folder generates a path too large for the link.
        Response := Execute(Enum::"Message Type ori"::"Storage.Attachment.Offload", RequestJson);
        // [THEN] No link or remote orphan is created and the blob is still local and readable.
        AssertRefusal(Response, 'LimitExceeded');
        LibraryAssert.IsFalse(Link.Get(Database::"Incoming Document Attachment", AttachmentId), 'Rejected offload must not insert a link.');
        LibraryAssert.AreEqual(0, MockState.FilePaths().Count(), 'Rejected offload must not create a remote orphan.');
        Attachment.GetBySystemId(AttachmentId);
        Attachment.CalcFields(Content);
        LibraryAssert.IsTrue(Attachment.Content.HasValue(), 'The only local copy must not be cleared.');
        LibraryAssert.IsTrue(Attachment.GetContent(TempBlob), 'The restored content must remain available.');
        TempBlob.CreateInStream(ContentIn);
        ContentIn.ReadText(ContentText);
        LibraryAssert.AreEqual('original', ContentText, 'Rejected offload must preserve every byte.');
    end;

    /// <summary>A failed remote move rolls back the prepared link updates.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC04_ConnectorMoveFailure_RollsBackLink()
    var
        MockState: Codeunit "Storage Mock State";
        AttachmentId: Guid;
    begin
        // Story #75, AC04 | Time: no date dependence | Risk: external writes are not database transactions.
        Initialize();
        // [GIVEN] A linked file and a connector that rejects before changing bytes.
        AttachmentId := CreateLinked('Xdir/Xfile.txt');
        MockState.FailNextWrite();
        // [WHEN] A move fails after preparing the database link change.
        asserterror Execute(Enum::"Message Type ori"::"Storage.File.Move", TransferRequest('Xdir/Xfile.txt', 'Xnew.txt'));
        // [THEN] The actual message transaction restored the old link and no target exists.
        LibraryAssert.ExpectedError('Injected storage write failure.');
        AssertLinkedContent(AttachmentId, 'Xdir/Xfile.txt');
        LibraryAssert.IsFalse(MockState.HasFile('Xnew.txt'), 'A rejected provider write must leave no orphan.');
    end;

    /// <summary>A self move through a slash alias is refused without deleting the unlinked source.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_SelfMoveAlias_PreservesSource()
    var
        Response: JsonObject;
    begin
        // Story #75, AC01 | Time: no date dependence | Risk: copy-then-delete self move loses bytes.
        Initialize();
        // [GIVEN] An unlinked file and two spellings of its identity.
        AssertSuccess(Execute(Enum::"Message Type ori"::"Storage.File.Create", ContentRequest('Xfile.txt', 'original')));
        // [WHEN] The source and destination normalize to the same file.
        Response := Execute(Enum::"Message Type ori"::"Storage.File.Move", TransferRequest('/Xfile.txt/', 'Xfile.txt'));
        // [THEN] The operation is refused before copy or deletion.
        AssertRefusal(Response, 'InvalidParameter');
        LibraryAssert.AreEqual('original', StoredText('Xfile.txt'), 'Self move must not remove the source.');
    end;

    /// <summary>A canonical relative path addresses the same file under a slash-spelled base root.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_BaseRootAlias_PreservesIntendedTarget()
    var
        StorageSetup: Record "Storage Setup ori";
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
        AttachmentId: Guid;
    begin
        // Story #75, AC01 | Time: no date dependence | Risk: base-root and relative-path composition.
        Initialize();
        // [GIVEN] A base path whose outer slashes are accepted by the real adapter.
        StorageSetup.Get(MockCodeTok);
        StorageSetup."Base Path" := '/Xbase/';
        StorageSetup.Modify();
        AttachmentId := CreateLinked('/Xdir/Xfile.txt/');
        LibraryAssert.IsTrue(MockState.HasFile('Xbase/Xdir/Xfile.txt'), 'The exact provider key must include the canonical base once.');
        // [WHEN] Root deletion addresses the configured base.
        Response := Execute(Enum::"Message Type ori"::"Storage.Directory.Delete", PathRequest('/'));
        // [THEN] The linked file and its canonical relative address survive.
        AssertRefusal(Response, 'PreconditionFailed');
        AssertLinkedContent(AttachmentId, 'Xdir/Xfile.txt');
    end;

    local procedure Initialize()
    var
        StorageSetup: Record "Storage Setup ori";
        Link: Record "Storage Attachment Link ori";
        MockState: Codeunit "Storage Mock State";
    begin
        MockState.Reset();
        Link.SetRange("Storage Code", MockCodeTok);
        Link.DeleteAll();
        if StorageSetup.Get(MockCodeTok) then
            StorageSetup.Delete();
        StorageSetup.Init();
        StorageSetup.Code := MockCodeTok;
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::Mock;
        StorageSetup.Enabled := true;
        StorageSetup.Insert();
    end;

    local procedure CreateLinked(Path: Text) AttachmentId: Guid
    var
        RequestJson: JsonObject;
        Response: JsonObject;
    begin
        AssertSuccess(Execute(Enum::"Message Type ori"::"Storage.File.Create", ContentRequest(Path, 'original')));
        RequestJson := PathRequest(Path);
        RequestJson.Add('fileName', 'Xfile.txt');
        Response := Execute(Enum::"Message Type ori"::"Storage.Attachment.CreateLinked", RequestJson);
        AssertSuccess(Response);
        Evaluate(AttachmentId, DataText(Response, 'systemId'));
    end;

    local procedure AssertLinkedContent(AttachmentId: Guid; ExpectedPath: Text)
    var
        Attachment: Record "Incoming Document Attachment";
        Link: Record "Storage Attachment Link ori";
        TempBlob: Codeunit "Temp Blob";
        ContentIn: InStream;
        ContentText: Text;
    begin
        Link.Get(Database::"Incoming Document Attachment", AttachmentId);
        LibraryAssert.AreEqual(ExpectedPath, Link."Storage Path", 'The attachment link must retain its intended address.');
        LibraryAssert.AreEqual('original', StoredText(ExpectedPath), 'Provider bytes must remain intact.');
        Attachment.GetBySystemId(AttachmentId);
        LibraryAssert.IsTrue(Attachment.GetContent(TempBlob), 'The actual attachment read hook must serve content.');
        TempBlob.CreateInStream(ContentIn);
        ContentIn.ReadText(ContentText);
        LibraryAssert.AreEqual('original', ContentText, 'Attachment readback must preserve the original bytes.');
    end;

    local procedure PathRequest(Path: Text) RequestJson: JsonObject
    begin
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('path', Path);
    end;

    local procedure ContentRequest(Path: Text; ContentText: Text) RequestJson: JsonObject
    var
        Base64Convert: Codeunit "Base64 Convert";
    begin
        RequestJson := PathRequest(Path);
        RequestJson.Add('contentBase64', Base64Convert.ToBase64(ContentText));
    end;

    local procedure TransferRequest(SourcePath: Text; TargetPath: Text) RequestJson: JsonObject
    begin
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('sourcePath', SourcePath);
        RequestJson.Add('targetPath', TargetPath);
    end;

    local procedure StoredText(Path: Text): Text
    var
        Base64Convert: Codeunit "Base64 Convert";
        Response: JsonObject;
    begin
        Response := Execute(Enum::"Message Type ori"::"Storage.File.Get", PathRequest(Path));
        AssertSuccess(Response);
        exit(Base64Convert.FromBase64(DataText(Response, 'contentBase64')));
    end;

    local procedure LongPath(PathLength: Integer) Path: Text
    begin
        while StrLen(Path) < PathLength - 100 do
            Path += 'X123456789/';
        Path += PadStr('X', PathLength - StrLen(Path) - 4, 'a') + '.txt';
    end;

    local procedure Execute(MessageType: Enum "Message Type ori"; RequestJson: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        MessageVersion: Enum "Message Version ori";
        ResponseContentType: Text[100];
        RequestText: Text;
        ResponseText: Text;
    begin
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        // Raw storage writes are irreversible contracts; exercise their normal commit mode.
        // RequiredTestIsolation=Function restores all database fixtures after each test.
        Dispatcher.Execute(MessageType, MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType, false);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure AssertSuccess(Response: JsonObject)
    begin
        LibraryAssert.AreEqual('Success', ReadText(Response, 'status'), 'The fixture operation must succeed.');
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text)
    begin
        LibraryAssert.AreEqual('Error', ReadText(Response, 'status'), 'The unsafe operation must fail.');
        LibraryAssert.AreEqual(ExpectedCode, ReadText(Response, 'code'), 'The error must carry a stable code.');
        LibraryAssert.AreNotEqual('', ReadText(Response, 'nextStep'), 'The rejection must tell the caller how to proceed.');
    end;

    local procedure ReadText(ValueObject: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(ValueObject.Get(PropertyName, Token), 'Expected response property: ' + PropertyName);
        exit(Token.AsValue().AsText());
    end;

    local procedure DataText(Response: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(Response.Get('data', Token), 'A success response must contain data.');
        exit(ReadText(Token.AsObject(), PropertyName));
    end;
}
