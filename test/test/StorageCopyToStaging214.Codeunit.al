namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Issue 214: Storage.File.CopyToStaging copies one storage file into one Foundation staging row.</summary>
codeunit 96280 "Storage CopyToStaging 214 ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "DataExch Fixture ori";
        LibraryAssert: Codeunit "Library Assert";

    /// <summary>AC01: a stored file becomes exactly one staging row; the storage file is unchanged.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_CopiesFileToStaging()
    begin
        CheckCopy(1033);
    end;

    /// <summary>AC01 again in 1039 (tests run twice, once per language).</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_CopiesFileToStaging_1039()
    begin
        CheckCopy(1039);
    end;

    /// <summary>AC02: an unknown storage code is refused and no staging row is created.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC02_UnknownStorageCode_RecordNotFound()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Fixture.InitializeStorage();
        Request.Add('storageCode', 'X214-NOT-CONFIGURED');
        Request.Add('path', 'in/a.bin');
        Response := Fixture.Dispatch("Message Type ori"::"Storage.File.CopyToStaging", Request);
        Fixture.AssertRefusal(Response, 'RecordNotFound', 'storageCode');
        LibraryAssert.AreEqual('', Fixture.ReadText(Response, 'stagingId'), 'No staging id on a refusal.');
    end;

    /// <summary>AC02: a missing file is refused as RecordNotFound on path.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC02_MissingFile_RecordNotFound()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Fixture.InitializeStorage();
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'in/missing214.bin');
        Response := Fixture.Dispatch("Message Type ori"::"Storage.File.CopyToStaging", Request);
        Fixture.AssertRefusal(Response, 'RecordNotFound', 'path');
        LibraryAssert.AreEqual('', Fixture.ReadText(Response, 'stagingId'), 'No staging id on a refusal.');
    end;

    /// <summary>AC02: a request without path is refused before any read.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC02_MissingPath_MissingParameter()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Fixture.InitializeStorage();
        Request.Add('storageCode', Fixture.StorageCode());
        Response := Fixture.Dispatch("Message Type ori"::"Storage.File.CopyToStaging", Request);
        Fixture.AssertRefusal(Response, 'MissingParameter', 'path');
    end;

    /// <summary>AC03: a file over the limit is refused with LimitExceeded and no row is created.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC03_OverLimit_LimitExceeded()
    var
        StorageSetup: Record "Storage Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        MockState: Codeunit "Storage Mock State";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        Response: JsonObject;
    begin
        Fixture.InitializeStorage();
        StorageSetup.Get(Fixture.StorageCode());
        MockState.PutFile('in/big214.bin', Fixture.Encode('0123456789A'));
        TempArgument.Init();
        TempArgument.Type := TempArgument.Type::"Storage.File.CopyToStaging";
        TempArgument.Insert(true);
        Connector := Enum::"Storage Type ori"::"Test Mock";

        RequestMgt.ExecuteCopyToStaging(TempArgument, StorageSetup, Connector, 'in/big214.bin', '', 10);

        Response := TempArgument.GetResponseJson();
        Fixture.AssertRefusal(Response, 'LimitExceeded', 'path');
        LibraryAssert.AreEqual('', Fixture.ReadText(Response, 'stagingId'), 'No staging id on a refusal.');
        LibraryAssert.IsTrue(MockState.HasFile('in/big214.bin'), 'The storage file stays.');
        // exactly at the limit is staged
        Clear(TempArgument);
        TempArgument.Init();
        TempArgument.Type := TempArgument.Type::"Storage.File.CopyToStaging";
        TempArgument.Insert(true);
        RequestMgt.ExecuteCopyToStaging(TempArgument, StorageSetup, Connector, 'in/big214.bin', '', 11);
        Response := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'A file exactly at the limit is staged.');
    end;

    /// <summary>AC04: the contract is complete: parameters, response, errors, effect, workflow, help.</summary>
    [Test]
    procedure Scenario_AC04_ContractIsComplete()
    var
        Contract: Codeunit "Storage Contract Parts ori";
        Guide: Codeunit "Storage Contract Guide ori";
        Workflow: JsonObject;
        Notes: Text;
        Effect: JsonObject;
        Token: JsonToken;
    begin
        LibraryAssert.AreEqual(3, Contract.GetParameters('Storage.File.CopyToStaging').Count(), 'storageCode, path and contentType.');
        LibraryAssert.AreEqual(5, GetFieldCount(Contract.GetResponse('Storage.File.CopyToStaging')), 'stagingId, size, contentType, fileName and nextStep.');
        LibraryAssert.IsTrue(Contract.GetErrors('Storage.File.CopyToStaging').Count() >= 3, 'RecordNotFound, LimitExceeded and MissingParameter are documented.');
        Effect := Contract.GetEffect('Storage.File.CopyToStaging');
        LibraryAssert.IsTrue(Effect.Get('effect', Token), 'An effect is declared.');
        LibraryAssert.AreEqual('write', Token.AsValue().AsText(), 'The effect is write.');
        LibraryAssert.IsTrue(Guide.GetWorkflow('Storage.File.CopyToStaging', Workflow), 'A workflow chapter exists.');
        LibraryAssert.IsTrue(Guide.GetNotes('Storage.File.CopyToStaging', Notes), 'Notes exist.');
        LibraryAssert.AreNotEqual('', Contract.GetOverview('Storage.File.CopyToStaging'), 'An overview exists.');
        LibraryAssert.IsTrue(Contract.GetExamples('Storage.File.CopyToStaging').Count() >= 1, 'Examples exist.');
    end;

    local procedure GetFieldCount(Response: JsonObject): Integer
    var
        Token: JsonToken;
    begin
        if Response.Get('fields', Token) then
            exit(Token.AsArray().Count());
        if Response.Get('data', Token) then
            exit(Token.AsArray().Count());
        exit(-1);
    end;

    local procedure CheckCopy(Lcid: Integer)
    var
        MockState: Codeunit "Storage Mock State";
        Staging: Codeunit "Blob Staging ori";
        TempBlob: Codeunit "Temp Blob";
        InStr: InStream;
        Content: Text;
        Request: JsonObject;
        Response: JsonObject;
        DataObject: JsonObject;
        StagingId: Guid;
    begin
        // [GIVEN] a stored file in the mock connection
        Fixture.InitializeStorage();
        Content := 'attachments-214 payload ' + Format(Lcid);
        MockState.PutFile('in/payload214.pdf', Fixture.Encode(Content));
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'in/payload214.pdf');
        Request.Add('contentType', 'application/pdf');
        Request.Add('lcid', Lcid);

        // [WHEN] it is copied to staging
        Response := Fixture.Dispatch("Message Type ori"::"Storage.File.CopyToStaging", Request);

        // [THEN] one staging row holds the same bytes; the storage file is unchanged
        DataObject := Fixture.Data(Response);
        LibraryAssert.IsTrue(Evaluate(StagingId, Fixture.ReadText(DataObject, 'stagingId')), 'stagingId is a GUID.');
        LibraryAssert.AreEqual(StrLen(Content), Fixture.ReadInt(DataObject, 'size'), 'size is the byte count.');
        LibraryAssert.AreEqual('payload214.pdf', Fixture.ReadText(DataObject, 'fileName'), 'fileName is the leaf name.');
        LibraryAssert.AreEqual('application/pdf', Fixture.ReadText(DataObject, 'contentType'), 'contentType is echoed.');
        LibraryAssert.AreNotEqual('', Fixture.ReadText(DataObject, 'nextStep'), 'nextStep names the consumers.');
        LibraryAssert.IsTrue(Staging.Exists(StagingId), 'The staging row exists for the caller.');
        LibraryAssert.IsTrue(MockState.HasFile('in/payload214.pdf'), 'The storage file stays.');
        LibraryAssert.AreEqual(Fixture.Encode(Content), MockState.GetFileContent('in/payload214.pdf'), 'The storage file is unchanged.');
        LibraryAssert.IsTrue(Staging.Take(StagingId, TempBlob), 'Take consumes the row (owned cleanup).');
        TempBlob.CreateInStream(InStr);
        InStr.ReadText(Content);
        LibraryAssert.AreEqual('attachments-214 payload ' + Format(Lcid), Content, 'The staged bytes equal the storage bytes.');
        LibraryAssert.IsFalse(Staging.Exists(StagingId), 'The row is gone after Take.');
    end;
}
