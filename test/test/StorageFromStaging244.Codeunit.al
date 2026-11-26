namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>
/// Issue 244: Storage.File.CreateFromStaging and Storage.Attachment.CreateFromStaging turn one Foundation
/// staging row into stored content and consume the row; every refusal or failure keeps the row.
/// All scenarios use the Mock connector; no credentials and no real storage.
/// </summary>
codeunit 96284 "Storage FromStaging 244 ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "DataExch Fixture ori";
        LibraryAssert: Codeunit "Library Assert";
        Staging: Codeunit "Blob Staging ori";
        MockState: Codeunit "Storage Mock State";

    /// <summary>AC02/AC04: the staged bytes are written to the path and the staging row is taken (1033).</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC02_FileHappyPath_TakesStaging()
    begin
        CheckFileHappyPath(1033);
    end;

    /// <summary>AC02/AC04 again in 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC02_FileHappyPath_TakesStaging_1039()
    begin
        CheckFileHappyPath(1039);
    end;

    /// <summary>AC05: an existing destination is refused without overwrite; nothing is written, the row is kept.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC05_FileExistingDestination_Refused()
    var
        Request: JsonObject;
        Response: JsonObject;
        StagingId: Guid;
    begin
        // [GIVEN] a staged file and an existing destination
        Fixture.InitializeStorage();
        MockState.PutFile('out/exists244.txt', Fixture.Encode('old'));
        StagingId := Stage('new content', 'exists244.txt');

        // [WHEN] it is written without overwrite
        Request := FileRequest(StagingId, 'out/exists244.txt');
        Response := Fixture.Dispatch("Message Type ori"::"Storage.File.CreateFromStaging", Request);

        // [THEN] PreconditionFailed on path; the file and the staging row are unchanged
        Fixture.AssertRefusal(Response, 'PreconditionFailed', 'path');
        LibraryAssert.AreEqual(Fixture.Encode('old'), MockState.GetFileContent('out/exists244.txt'), 'The existing file is unchanged.');
        AssertKeptAndRelease(StagingId);
    end;

    /// <summary>AC05: overwrite true replaces an existing unlinked file and takes the row.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC05_FileOverwriteTrue_Replaces()
    var
        Request: JsonObject;
        Response: JsonObject;
        StagingId: Guid;
    begin
        Fixture.InitializeStorage();
        MockState.PutFile('out/replace244.txt', Fixture.Encode('old'));
        StagingId := Stage('replacement', 'replace244.txt');
        Request := FileRequest(StagingId, 'out/replace244.txt');
        Request.Add('overwrite', true);

        Response := Fixture.Dispatch("Message Type ori"::"Storage.File.CreateFromStaging", Request);

        LibraryAssert.IsTrue(Fixture.ReadBool(Fixture.Data(Response), 'overwritten'), 'overwritten is true.');
        LibraryAssert.AreEqual(Fixture.Encode('replacement'), MockState.GetFileContent('out/replace244.txt'), 'The file holds the staged bytes.');
        LibraryAssert.IsFalse(Staging.Exists(StagingId), 'The staging row is taken.');
    end;

    /// <summary>AC06: a destination linked to an attachment is refused even with overwrite true.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC06_FileLinkedDestination_Refused()
    var
        Link: Record "Storage Attachment Link ori";
        Request: JsonObject;
        Response: JsonObject;
        StagingId: Guid;
        LinkId: Guid;
    begin
        // [GIVEN] a destination that backs an attachment
        Fixture.InitializeStorage();
        MockState.PutFile('out/linked244.txt', Fixture.Encode('linked'));
        LinkId := CreateGuid();
        Link.Init();
        Link."Table ID" := Database::"Document Attachment";
        Link."Record System Id" := LinkId;
        Link."Storage Code" := CopyStr(Fixture.StorageCode(), 1, MaxStrLen(Link."Storage Code"));
        Link."Storage Path" := 'out/linked244.txt';
        Link."File Name" := 'linked244.txt';
        Link.Insert();
        Commit();
        StagingId := Stage('intruder', 'linked244.txt');
        Request := FileRequest(StagingId, 'out/linked244.txt');
        Request.Add('overwrite', true);

        // [WHEN] it is overwritten
        Response := Fixture.Dispatch("Message Type ori"::"Storage.File.CreateFromStaging", Request);

        // [THEN] PreconditionFailed on path; the linked file and the staging row are unchanged
        Fixture.AssertRefusal(Response, 'PreconditionFailed', 'path');
        LibraryAssert.AreEqual(Fixture.Encode('linked'), MockState.GetFileContent('out/linked244.txt'), 'The linked file is unchanged.');
        AssertKeptAndRelease(StagingId);
        Link.Get(Database::"Document Attachment", LinkId);
        Link.Delete();
    end;

    /// <summary>AC07/AC08: an unknown and an already consumed stagingId get the same RecordNotFound answer.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC07_UnknownAndConsumedStaging_SameAnswer()
    var
        TempBlob: Codeunit "Temp Blob";
        Response: JsonObject;
        ConsumedResponse: JsonObject;
        UnknownId: Guid;
        ConsumedId: Guid;
    begin
        Fixture.InitializeStorage();
        UnknownId := CreateGuid();
        ConsumedId := Stage('gone', 'gone244.txt');
        LibraryAssert.IsTrue(Staging.Take(ConsumedId, TempBlob), 'Consume the row first.');
        Commit();

        Response := Fixture.Dispatch("Message Type ori"::"Storage.File.CreateFromStaging", FileRequest(UnknownId, 'out/unknown244.txt'));
        ConsumedResponse := Fixture.Dispatch("Message Type ori"::"Storage.File.CreateFromStaging", FileRequest(ConsumedId, 'out/unknown244.txt'));

        Fixture.AssertRefusal(Response, 'RecordNotFound', 'stagingId');
        Fixture.AssertRefusal(ConsumedResponse, 'RecordNotFound', 'stagingId');
        LibraryAssert.AreEqual(
            Fixture.ReadText(Response, 'error').Replace(Format(UnknownId, 0, 4), '<id>'),
            Fixture.ReadText(ConsumedResponse, 'error').Replace(Format(ConsumedId, 0, 4), '<id>'),
            'The answer does not reveal whether a row existed.');
        LibraryAssert.IsFalse(MockState.HasFile('out/unknown244.txt'), 'Nothing was written.');
    end;

    /// <summary>AC08: missing stagingId, empty content and an invalid path are refused with distinct errors.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC08_MissingEmptyAndInvalidPath_Refused()
    var
        Request: JsonObject;
        Response: JsonObject;
        StagingId: Guid;
    begin
        Fixture.InitializeStorage();
        // Missing stagingId
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'out/missing244.txt');
        Response := Fixture.Dispatch("Message Type ori"::"Storage.File.CreateFromStaging", Request);
        Fixture.AssertRefusal(Response, 'MissingParameter', 'stagingId');

        // Empty staged content
        StagingId := Stage('', 'empty244.txt');
        // A refusal after the Take is raised so the API path rolls the Take back.
        AssertRaised("Message Type ori"::"Storage.File.CreateFromStaging", FileRequest(StagingId, 'out/empty244.txt'), 'holds no content');
        LibraryAssert.IsFalse(MockState.HasFile('out/empty244.txt'), 'Nothing was written for empty content.');
        AssertKeptAndRelease(StagingId);

        // Invalid path
        StagingId := Stage('payload', 'path244.txt');
        Response := Fixture.Dispatch("Message Type ori"::"Storage.File.CreateFromStaging", FileRequest(StagingId, '../escape244.txt'));
        AssertRefusedOn(Response, 'path');
        AssertKeptAndRelease(StagingId);
    end;

    /// <summary>AC04: a connector failure after the Take rolls back and keeps the staging row.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC04_FileWriteFailure_KeepsStaging()
    var
        StagingId: Guid;
    begin
        Fixture.InitializeStorage();
        StagingId := Stage('fails', 'fail244.txt');
        MockState.FailNextWrite();

        AssertRaised("Message Type ori"::"Storage.File.CreateFromStaging", FileRequest(StagingId, 'out/fail244.txt'), 'staging row is kept');

        LibraryAssert.IsFalse(MockState.HasFile('out/fail244.txt'), 'Nothing was written.');
        AssertKeptAndRelease(StagingId);
    end;

    /// <summary>AC09: an expectedCount other than 1 is refused before any write.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC09_ExpectedCountMismatch_Refused()
    var
        Request: JsonObject;
        Response: JsonObject;
        StagingId: Guid;
    begin
        Fixture.InitializeStorage();
        StagingId := Stage('count', 'count244.txt');
        Request := FileRequest(StagingId, 'out/count244.txt');
        Request.Add('expectedCount', 2);

        Response := Fixture.Dispatch("Message Type ori"::"Storage.File.CreateFromStaging", Request);

        Fixture.AssertRefusal(Response, 'InvalidParameter', 'expectedCount');
        LibraryAssert.IsFalse(MockState.HasFile('out/count244.txt'), 'Nothing was written.');
        AssertKeptAndRelease(StagingId);

        // The attachment type checks the same confirmation.
        StagingId := Stage('count', 'count244.txt');
        Clear(Request);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('stagingId', Format(StagingId, 0, 4));
        Request.Add('target', 'IncomingDocument');
        Request.Add('expectedCount', 0);
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Attachment.CreateFromStaging", Request);
        Fixture.AssertRefusal(Response, 'InvalidParameter', 'expectedCount');
        AssertKeptAndRelease(StagingId);
    end;

    /// <summary>AC03/AC04: a staged file becomes an offloaded document attachment on a customer (1033).</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC03_AttachmentOnRecord_Offloaded()
    begin
        CheckRecordAttachment(1033);
    end;

    /// <summary>AC03/AC04 again in 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC03_AttachmentOnRecord_Offloaded_1039()
    begin
        CheckRecordAttachment(1039);
    end;

    /// <summary>AC03: a staged file becomes an offloaded incoming document attachment; fileName override wins.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC03_AttachmentIncomingDocument_Offloaded()
    var
        Link: Record "Storage Attachment Link ori";
        IncomingAttachment: Record "Incoming Document Attachment";
        Request: JsonObject;
        DataObject: JsonObject;
        StagingId: Guid;
        RecSystemId: Guid;
        Path: Text;
    begin
        Fixture.InitializeStorage();
        StagingId := Stage('incoming 244', 'staged-name.pdf');
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('stagingId', Format(StagingId, 0, 4));
        Request.Add('target', 'IncomingDocument');
        Request.Add('fileName', 'invoice244.pdf');
        Request.Add('expectedCount', 1);

        DataObject := Fixture.Data(Fixture.Dispatch("Message Type ori"::"Storage.Attachment.CreateFromStaging", Request));

        LibraryAssert.AreEqual('IncomingDocument', Fixture.ReadText(DataObject, 'target'), 'target');
        LibraryAssert.AreEqual('invoice244.pdf', Fixture.ReadText(DataObject, 'fileName'), 'The fileName override is used.');
        LibraryAssert.IsTrue(Fixture.ReadBool(DataObject, 'offloaded'), 'The attachment is offloaded.');
        Path := Fixture.ReadText(DataObject, 'path');
        LibraryAssert.AreEqual(Fixture.Encode('incoming 244'), MockState.GetFileContent(Path), 'Storage holds the staged bytes.');
        Evaluate(RecSystemId, Fixture.ReadText(DataObject, 'systemId'));
        LibraryAssert.IsTrue(Link.Get(Database::"Incoming Document Attachment", RecSystemId), 'A storage link exists.');
        LibraryAssert.IsTrue(IncomingAttachment.GetBySystemId(RecSystemId), 'The incoming document attachment exists.');
        LibraryAssert.IsFalse(Staging.Exists(StagingId), 'The staging row is taken.');
        Fixture.CleanupStorage(CopyStr(Fixture.StorageCode(), 1, 20));
    end;

    /// <summary>AC05/AC04: an existing attachment destination is refused; no attachment is created and the row is kept.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC05_AttachmentExistingDestination_Refused()
    var
        DocumentAttachment: Record "Document Attachment";
        CustomerNo: Code[20];
        Request: JsonObject;
        StagingId: Guid;
    begin
        Fixture.InitializeStorage();
        CustomerNo := Fixture.CreateCustomers(1, 'X244').Get(1);
        MockState.PutFile('x244/taken.txt', Fixture.Encode('old'));
        Commit();
        StagingId := Stage('new', 'taken.txt');
        Request := RecordRequest(StagingId, CustomerNo);
        Request.Add('folderPath', 'x244');

        AssertRaised("Message Type ori"::"Storage.Attachment.CreateFromStaging", Request, 'already exists');

        DocumentAttachment.SetRange("Table ID", Database::Customer);
        DocumentAttachment.SetRange("No.", CustomerNo);
        LibraryAssert.IsTrue(DocumentAttachment.IsEmpty(), 'No attachment was created.');
        LibraryAssert.AreEqual(Fixture.Encode('old'), MockState.GetFileContent('x244/taken.txt'), 'The existing file is unchanged.');
        AssertKeptAndRelease(StagingId);
        DeleteCustomer(CustomerNo);
    end;

    /// <summary>AC04: a failed upload rolls back the attachment and keeps the staging row.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC04_AttachmentUploadFailure_KeepsStaging()
    var
        DocumentAttachment: Record "Document Attachment";
        CustomerNo: Code[20];
        StagingId: Guid;
    begin
        Fixture.InitializeStorage();
        CustomerNo := Fixture.CreateCustomers(1, 'X244').Get(1);
        Commit();
        StagingId := Stage('fails', 'fail244.txt');
        MockState.FailNextWrite();

        AssertRaised("Message Type ori"::"Storage.Attachment.CreateFromStaging", RecordRequest(StagingId, CustomerNo), 'Injected storage write failure');

        DocumentAttachment.SetRange("Table ID", Database::Customer);
        DocumentAttachment.SetRange("No.", CustomerNo);
        LibraryAssert.IsTrue(DocumentAttachment.IsEmpty(), 'The attachment was rolled back.');
        AssertKeptAndRelease(StagingId);
        DeleteCustomer(CustomerNo);
    end;

    /// <summary>AC07: the attachment type gives the same not-found answer for an unknown stagingId.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC07_AttachmentUnknownStaging_RecordNotFound()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Fixture.InitializeStorage();
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('stagingId', Format(CreateGuid(), 0, 4));
        Request.Add('target', 'IncomingDocument');

        Response := Fixture.Dispatch("Message Type ori"::"Storage.Attachment.CreateFromStaging", Request);

        Fixture.AssertRefusal(Response, 'RecordNotFound', 'stagingId');
    end;

    /// <summary>AC01/AC03/AC09/AC10: both types are Inbound write types with contract chapters and BIFROST Attach ori.</summary>
    [Test]
    procedure Scenario_AC09_BothTypesAreWritesWithContracts()
    begin
        AssertWriteContract('Storage.File.CreateFromStaging', Enum::"Message Type ori"::"Storage.File.CreateFromStaging");
        AssertWriteContract('Storage.Attachment.CreateFromStaging', Enum::"Message Type ori"::"Storage.Attachment.CreateFromStaging");
    end;

    local procedure CheckFileHappyPath(Lcid: Integer)
    var
        Request: JsonObject;
        DataObject: JsonObject;
        StagingId: Guid;
        Content: Text;
    begin
        // [GIVEN] one staged file
        Fixture.InitializeStorage();
        Content := 'attachments-244 payload ' + Format(Lcid);
        StagingId := Stage(Content, 'payload244.txt');
        Request := FileRequest(StagingId, 'out/payload244.txt');
        Request.Add('expectedCount', 1);
        Request.Add('lcid', Lcid);

        // [WHEN] it is written to storage
        DataObject := Fixture.Data(Fixture.Dispatch("Message Type ori"::"Storage.File.CreateFromStaging", Request));

        // [THEN] the file holds the staged bytes and the staging row no longer exists
        LibraryAssert.AreEqual('out/payload244.txt', Fixture.ReadText(DataObject, 'path'), 'path');
        LibraryAssert.AreEqual(StrLen(Content), Fixture.ReadInt(DataObject, 'contentLength'), 'contentLength');
        LibraryAssert.AreEqual(Format(StagingId, 0, 4), Fixture.ReadText(DataObject, 'stagingId'), 'stagingId is echoed.');
        LibraryAssert.IsFalse(Fixture.ReadBool(DataObject, 'overwritten'), 'A new file is not an overwrite.');
        LibraryAssert.AreEqual(Fixture.Encode(Content), MockState.GetFileContent('out/payload244.txt'), 'Storage holds the staged bytes.');
        LibraryAssert.IsFalse(Staging.Exists(StagingId), 'The staging row is taken.');
        // A follow-up call with the same stagingId is not found.
        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"Storage.File.CreateFromStaging", FileRequest(StagingId, 'out/again244.txt')), 'RecordNotFound', 'stagingId');
    end;

    local procedure CheckRecordAttachment(Lcid: Integer)
    var
        Link: Record "Storage Attachment Link ori";
        DocumentAttachment: Record "Document Attachment";
        CustomerNo: Code[20];
        Request: JsonObject;
        DataObject: JsonObject;
        StagingId: Guid;
        RecSystemId: Guid;
        Path: Text;
    begin
        // [GIVEN] a customer and one staged file
        Fixture.InitializeStorage();
        CustomerNo := Fixture.CreateCustomers(1, 'X244').Get(1);
        Commit();
        StagingId := Stage('record 244 ' + Format(Lcid), 'contract244.txt');
        Request := RecordRequest(StagingId, CustomerNo);
        Request.Add('expectedCount', 1);
        Request.Add('lcid', Lcid);

        // [WHEN] it becomes an attachment
        DataObject := Fixture.Data(Fixture.Dispatch("Message Type ori"::"Storage.Attachment.CreateFromStaging", Request));

        // [THEN] an offloaded attachment with a link; storage holds the bytes; the row is taken
        LibraryAssert.AreEqual('DocumentAttachment', Fixture.ReadText(DataObject, 'target'), 'target');
        LibraryAssert.AreEqual('contract244.txt', Fixture.ReadText(DataObject, 'fileName'), 'The staged file name is the default.');
        LibraryAssert.IsTrue(Fixture.ReadBool(DataObject, 'offloaded'), 'The attachment is offloaded.');
        Path := Fixture.ReadText(DataObject, 'path');
        LibraryAssert.AreEqual(Fixture.Encode('record 244 ' + Format(Lcid)), MockState.GetFileContent(Path), 'Storage holds the staged bytes.');
        Evaluate(RecSystemId, Fixture.ReadText(DataObject, 'systemId'));
        LibraryAssert.IsTrue(Link.Get(Database::"Document Attachment", RecSystemId), 'A storage link exists.');
        LibraryAssert.IsTrue(DocumentAttachment.GetBySystemId(RecSystemId), 'The attachment exists.');
        LibraryAssert.AreEqual(CustomerNo, DocumentAttachment."No.", 'The attachment is on the customer.');
        LibraryAssert.IsFalse(Staging.Exists(StagingId), 'The staging row is taken.');
        Fixture.CleanupStorage(CopyStr(Fixture.StorageCode(), 1, 20));
        DeleteCustomer(CustomerNo);
    end;

    local procedure AssertWriteContract(TypeName: Text; MessageType: Enum "Message Type ori")
    var
        Contract: Codeunit "Storage Contract Parts ori";
        MsgInterface: Interface "Msg Interface ori";
        Effect: JsonObject;
        Token: JsonToken;
    begin
        Effect := Contract.GetEffect(TypeName);
        Effect.Get('effect', Token);
        LibraryAssert.AreEqual('write', Token.AsValue().AsText(), TypeName + ' is a write type.');
        Effect.Get('permissionSet', Token);
        LibraryAssert.AreEqual('BIFROST Attach ori', Token.AsValue().AsText(), TypeName + ' needs the write permission set.');
        LibraryAssert.AreNotEqual('', Contract.GetOverview(TypeName), TypeName + ' has an overview.');
        LibraryAssert.IsTrue(Contract.GetParameters(TypeName).Count() >= 4, TypeName + ' documents its parameters.');
        LibraryAssert.IsTrue(Contract.GetErrors(TypeName).Count() >= 4, TypeName + ' documents its errors.');
        LibraryAssert.IsTrue(Contract.GetExamples(TypeName).Count() >= 1, TypeName + ' has examples.');
        MsgInterface := MessageType;
        LibraryAssert.AreEqual(Enum::"Msg Direction ori"::Inbound, MsgInterface.GetMessageDirection(), TypeName + ' is Inbound.');
    end;

    local procedure Stage(Content: Text; FileName: Text) StagingId: Guid
    var
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        InStr: InStream;
    begin
        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        if Content <> '' then
            OutStr.WriteText(Content);
        TempBlob.CreateInStream(InStr);
        StagingId := Staging.Create(InStr, FileName, 'text/plain', 'Storage FromStaging 244 test');
        Commit();
    end;

    local procedure FileRequest(StagingId: Guid; Path: Text) Request: JsonObject
    begin
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', Path);
        Request.Add('stagingId', Format(StagingId, 0, 4));
    end;

    local procedure RecordRequest(StagingId: Guid; CustomerNo: Code[20]) Request: JsonObject
    begin
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('stagingId', Format(StagingId, 0, 4));
        Request.Add('tableId', Database::Customer);
        Request.Add('no', CustomerNo);
    end;

    local procedure AssertKeptAndRelease(StagingId: Guid)
    var
        TempBlob: Codeunit "Temp Blob";
    begin
        LibraryAssert.IsTrue(Staging.Exists(StagingId), 'The staging row is kept.');
        LibraryAssert.IsTrue(Staging.Take(StagingId, TempBlob), 'Owned cleanup of the kept row.');
        Commit();
    end;

    local procedure AssertRaised(MessageType: Enum "Message Type ori"; Request: JsonObject; ExpectedText: Text)
    begin
        asserterror Fixture.Dispatch(MessageType, Request);
        LibraryAssert.IsTrue(GetLastErrorText().Contains(ExpectedText), 'Expected "' + ExpectedText + '" in: ' + GetLastErrorText());
    end;

    local procedure AssertRefusedOn(Response: JsonObject; ParameterName: Text)
    var
        ResponseText: Text;
    begin
        LibraryAssert.AreEqual('Error', Fixture.ReadText(Response, 'status'), 'The call must be refused.');
        Response.WriteTo(ResponseText);
        LibraryAssert.IsTrue(ResponseText.Contains('"parameter":"' + ParameterName + '"'), 'The refusal names ' + ParameterName + ': ' + ResponseText);
    end;

    local procedure DeleteCustomer(CustomerNo: Code[20])
    var
        Customer: Record Customer;
        DocumentAttachment: Record "Document Attachment";
    begin
        DocumentAttachment.SetRange("Table ID", Database::Customer);
        DocumentAttachment.SetRange("No.", CustomerNo);
        DocumentAttachment.DeleteAll(true);
        if Customer.Get(CustomerNo) then
            Customer.Delete(true);
        Commit();
    end;
}
