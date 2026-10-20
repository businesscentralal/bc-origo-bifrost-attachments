namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.Utilities;
using System.Text;

/// <summary>
/// Phase 2 (#23): incoming documents with Data Exchange Type on CommitToRecord and CreateLinked.
/// </summary>
codeunit 96237 "DataExch Phase2 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        MockCodeTok: Label 'MOCK', Locked = true;
        TypeSetHintTok: Label 'DataExchange.Type.Set', Locked = true;

    /// <summary>Verifies persisted processing errors are scoped to one document and have bilingual next steps.</summary>
    [Test]
    procedure PersistedProcessingErrors_AreScopedAndBilingual()
    begin
        AssertPersistedProcessingErrors(1033, 'Inspect Incoming.Document.Get');
        AssertPersistedProcessingErrors(1039, 'Skoðaðu Incoming.Document.Get');
    end;

    local procedure AssertPersistedProcessingErrors(LanguageId: Integer; ExpectedNextStep: Text)
    var
        IncomingDocument: Record "Incoming Document";
        OtherDocument: Record "Incoming Document";
        ErrorMessage: Record "Error Message";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        ProcessErrors: JsonArray;
        Token: JsonToken;
        SavedLanguage: Integer;
    begin
        IncomingDocument.Get(IncomingDocument.CreateIncomingDocument('BIFT-167 error context', ''));
        OtherDocument.Get(OtherDocument.CreateIncomingDocument('BIFT-167 other context', ''));
        ErrorMessage.Init();
        ErrorMessage."Context Record ID" := OtherDocument.RecordId;
        ErrorMessage."Message Type" := ErrorMessage."Message Type"::Error;
        ErrorMessage.Message := 'Unrelated private failure';
        ErrorMessage.Insert(true);
        ErrorMessage.Init();
        ErrorMessage.ID := 0;
        ErrorMessage."Context Record ID" := IncomingDocument.RecordId;
        ErrorMessage."Message Type" := ErrorMessage."Message Type"::Error;
        ErrorMessage.Message := 'The selected definition has no target table.';
        ErrorMessage.Insert(true);
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        AttachmentMgt.CollectProcessErrors(IncomingDocument, '', ProcessErrors);
        GlobalLanguage(SavedLanguage);
        LibraryAssert.AreEqual(1, ProcessErrors.Count(), 'Only this document persisted error must be returned.');
        ProcessErrors.Get(0, Token);
        LibraryAssert.AreEqual('The selected definition has no target table.', ReadText(Token.AsObject(), 'message'), 'Return the actual persisted error.');
        LibraryAssert.AreEqual('BusinessCentralError', ReadText(Token.AsObject(), 'code'), 'Return a stable code.');
        LibraryAssert.IsTrue(ReadText(Token.AsObject(), 'nextStep').StartsWith(ExpectedNextStep), 'Next step must be translated.');
        ErrorMessage.SetRange("Context Record ID", IncomingDocument.RecordId);
        ErrorMessage.DeleteAll(true);
        ErrorMessage.SetRange("Context Record ID", OtherDocument.RecordId);
        ErrorMessage.DeleteAll(true);
        IncomingDocument.Delete(true);
        OtherDocument.Delete(true);
    end;

    [Test]
    procedure AC01_CommitToRecord_SetsDataExchangeType_LeavesUnprocessed()
    var
        IncomingDocument: Record "Incoming Document";
        Session: Record "Storage Upload Session ori";
        TempArgument: Record "Message Argument ori" temporary;
        TypeCode: Code[20];
        UploadId: Text;
        EntryNo: Integer;
        UploadGuid: Guid;
    begin
        // [SCENARIO] AC01: CommitToRecord IncomingDocument with an existing type sets the type and does not process.
        Initialize();
        TypeCode := SeedImportType();
        BeginAndAppend(UploadId, 'phase2-ac01.csv', 'vendor,amount');

        ExecuteCommit(TempArgument, UploadId, TypeCode, false, 'BIFT-P2-AC01');
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'AC01 status');
        EntryNo := ReadDataInt(TempArgument, 'incomingDocumentEntryNo');
        LibraryAssert.AreNotEqual(0, EntryNo, 'AC01 creates an incoming document.');
        LibraryAssert.AreEqual(TypeCode, ReadDataText(TempArgument, 'dataExchangeType'), 'AC01 echoes the type.');
        LibraryAssert.AreEqual(false, ReadDataBool(TempArgument, 'processed'), 'AC01 processed is false.');

        IncomingDocument.Get(EntryNo);
        LibraryAssert.AreEqual(TypeCode, IncomingDocument."Data Exchange Type", 'AC01 stored type.');
        Evaluate(UploadGuid, UploadId);
        Session.Get(UploadGuid);
        LibraryAssert.AreEqual(Session.Status::Committed, Session.Status, 'AC01 session is committed.');
    end;

    [Test]
    procedure AC02_CommitToRecord_ProcessTrue_KeepsDocumentOnProcessErrors()
    var
        IncomingDocument: Record "Incoming Document";
        TempArgument: Record "Message Argument ori" temporary;
        ResponseJson: JsonObject;
        ProcessErrors: JsonArray;
        Token: JsonToken;
        TypeCode: Code[20];
        UploadId: Text;
        EntryNo: Integer;
        DataObject: JsonObject;
    begin
        // [SCENARIO] AC02: process true returns Success with processErrors; the incoming document remains.
        Initialize();
        TypeCode := SeedImportType();
        BeginAndAppend(UploadId, 'phase2-ac02.csv', 'vendor,amount');

        ExecuteCommit(TempArgument, UploadId, TypeCode, true, 'BIFT-P2-AC02');
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'AC02 upload stays Success.');
        EntryNo := ReadDataInt(TempArgument, 'incomingDocumentEntryNo');
        LibraryAssert.AreNotEqual(0, EntryNo, 'AC02 keeps the incoming document.');
        LibraryAssert.IsTrue(IncomingDocument.Get(EntryNo), 'AC02 document exists after process.');
        DataObject := ReadData(ResponseJson);
        LibraryAssert.IsTrue(DataObject.Get('processErrors', Token), 'AC02 returns processErrors.');
        ProcessErrors := Token.AsArray();
        LibraryAssert.IsTrue(ProcessErrors.Count() > 0, 'Invalid processing must return its errors.');
        ProcessErrors.Get(0, Token);
        LibraryAssert.IsTrue(Token.IsObject(), 'Processing errors must be structured objects.');
        LibraryAssert.AreEqual('BusinessCentralError', ReadText(Token.AsObject(), 'code'), 'Stable processing error code.');
        LibraryAssert.AreNotEqual('', ReadText(Token.AsObject(), 'message'), 'Actual processing failure must be visible.');
        LibraryAssert.IsTrue(ReadText(Token.AsObject(), 'nextStep').Contains('Incoming.Document.Process'), 'Processing failure must offer a retry route.');
        LibraryAssert.AreNotEqual('', ReadText(DataObject, 'incomingDocumentStatus'), 'Return the incoming document status.');
        LibraryAssert.AreEqual(IncomingDocument."Document No." <> '', ReadDataBool(TempArgument, 'processed'), 'AC02 processed tracks a created document no.');
        if DataObject.Contains('createdDocument') then
            LibraryAssert.AreNotEqual('', IncomingDocument."Document No.", 'AC02 createdDocument matches a document no.');
    end;

    [Test]
    procedure AC03_UnknownType_RefusesBeforeWrite_SessionStaysOpen()
    var
        IncomingDocument: Record "Incoming Document";
        Session: Record "Storage Upload Session ori";
        TempArgument: Record "Message Argument ori" temporary;
        CommitReq: JsonObject;
        UploadId: Text;
        UploadGuid: Guid;
        BeforeCount: Integer;
    begin
        // [SCENARIO] AC03: unknown dataExchangeType is refused before any write; the session stays Open.
        Initialize();
        BeforeCount := IncomingDocument.Count();
        BeginAndAppend(UploadId, 'phase2-ac03.csv', 'vendor,amount');

        CommitReq.Add('uploadId', UploadId);
        CommitReq.Add('target', 'IncomingDocument');
        CommitReq.Add('description', 'BIFT-P2-AC03');
        CommitReq.Add('dataExchangeType', 'NO-SUCH-TYPE');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.CommitToRecord", CommitReq);

        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'AC03 status');
        LibraryAssert.AreEqual('RecordNotFound', ReadText(TempArgument.GetResponseJson(), 'code'), 'AC03 code');
        LibraryAssert.AreEqual('dataExchangeType', ReadText(TempArgument.GetResponseJson(), 'parameter'), 'AC03 parameter');
        LibraryAssert.AreEqual(BeforeCount, IncomingDocument.Count(), 'AC03 creates no incoming document.');
        Evaluate(UploadGuid, UploadId);
        Session.Get(UploadGuid);
        LibraryAssert.AreEqual(Session.Status::Open, Session.Status, 'AC03 session stays Open.');
    end;

    [Test]
    procedure AC04_CreateLinked_SetsTypeOnIncomingDocument()
    var
        IncomingDocument: Record "Incoming Document";
        Link: Record "Storage Attachment Link ori";
        TempArgument: Record "Message Argument ori" temporary;
        LinkReq: JsonObject;
        TypeCode: Code[20];
        UploadId: Text;
        Path: Text;
        EntryNo: Integer;
    begin
        // [SCENARIO] AC04: CreateLinked with dataExchangeType sets the type on a linked incoming document.
        Initialize();
        TypeCode := SeedImportType();
        BeginUpload('phase2-ac04.csv', UploadId, Path);
        AppendChunk(UploadId, 1, 'vendor,amount');
        CommitUpload(TempArgument, UploadId);

        Clear(TempArgument);
        LinkReq.Add('storageCode', MockCodeTok);
        LinkReq.Add('path', Path);
        LinkReq.Add('fileName', 'phase2-ac04.csv');
        LinkReq.Add('description', 'BIFT-P2-AC04');
        LinkReq.Add('dataExchangeType', TypeCode);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateLinked", LinkReq);

        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'AC04 status');
        EntryNo := ReadDataInt(TempArgument, 'incomingDocumentEntryNo');
        IncomingDocument.Get(EntryNo);
        LibraryAssert.AreEqual(TypeCode, IncomingDocument."Data Exchange Type", 'AC04 stored type.');
        Link.SetRange("Inc. Doc. Entry No.", EntryNo);
        LibraryAssert.AreEqual(1, Link.Count(), 'AC04 keeps the storage link.');
        LibraryAssert.AreEqual(false, ReadDataBool(TempArgument, 'processed'), 'AC04 does not process unless asked.');
        AssertLinkedContentServed(EntryNo, 'vendor,amount');
    end;

    [Test]
    procedure AC04_CreateLinked_ProcessTrue_KeepsDocumentAndLink()
    var
        IncomingDocument: Record "Incoming Document";
        Link: Record "Storage Attachment Link ori";
        TempArgument: Record "Message Argument ori" temporary;
        ResponseJson: JsonObject;
        DataObject: JsonObject;
        ProcessErrors: JsonArray;
        Token: JsonToken;
        LinkReq: JsonObject;
        TypeCode: Code[20];
        UploadId: Text;
        Path: Text;
        EntryNo: Integer;
    begin
        // [SCENARIO] AC04: CreateLinked with type and process keeps the incoming document and the storage link.
        Initialize();
        TypeCode := SeedImportType();
        BeginUpload('phase2-ac04-process.csv', UploadId, Path);
        AppendChunk(UploadId, 1, 'vendor,amount');
        CommitUpload(TempArgument, UploadId);

        Clear(TempArgument);
        LinkReq.Add('storageCode', MockCodeTok);
        LinkReq.Add('path', Path);
        LinkReq.Add('fileName', 'phase2-ac04-process.csv');
        LinkReq.Add('description', 'BIFT-P2-AC04P');
        LinkReq.Add('dataExchangeType', TypeCode);
        LinkReq.Add('process', true);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateLinked", LinkReq);

        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'AC04 process status stays Success.');
        EntryNo := ReadDataInt(TempArgument, 'incomingDocumentEntryNo');
        LibraryAssert.IsTrue(IncomingDocument.Get(EntryNo), 'AC04 process keeps the incoming document.');
        LibraryAssert.AreEqual(TypeCode, IncomingDocument."Data Exchange Type", 'AC04 process keeps the type.');
        Link.SetRange("Inc. Doc. Entry No.", EntryNo);
        LibraryAssert.AreEqual(1, Link.Count(), 'AC04 process keeps the storage link.');
        AssertLinkedContentServed(EntryNo, 'vendor,amount');
        DataObject := ReadData(ResponseJson);
        LibraryAssert.IsTrue(DataObject.Get('processErrors', Token), 'AC04 process returns processErrors.');
        ProcessErrors := Token.AsArray();
        LibraryAssert.IsTrue(
            DataObject.Contains('createdDocument') or (ProcessErrors.Count() > 0),
            'AC04 process returns a created document or base-app process errors.');
    end;

    [Test]
    procedure AC05_TypeSet_ExportDefinition_IsRefused()
    var
        Definition: Record "Data Exch. Def";
        ExchangeType: Record "Data Exchange Type";
        TempArgument: Record "Message Argument ori" temporary;
        RequestJson: JsonObject;
        TypeCode: Code[20];
        ErrorText: Text;
    begin
        // [SCENARIO] AC05: DataExchange.Type.Set with an export definition is refused and inserts no type.
        Initialize();
        TypeCode := NewFixtureCode();
        SeedDefinition(Definition, Definition.Type::"Generic Export");
        RequestJson.Add('code', TypeCode);
        RequestJson.Add('dataExchDefCode', Definition.Code);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"DataExchange.Type.Set", RequestJson);

        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'AC05 status');
        ErrorText := ReadText(TempArgument.GetResponseJson(), 'error');
        LibraryAssert.IsTrue(ErrorText.Contains('import') or ErrorText.Contains('accepted'), 'AC05 names the import restriction.');
        ExchangeType.SetRange(Code, TypeCode);
        LibraryAssert.IsTrue(ExchangeType.IsEmpty(), 'AC05 inserts no type.');
    end;

    [Test]
    procedure AC07_DataRecordsSet_BlocksIncomingTypeField_AndTypeTable()
    var
        IncomingDocument: Record "Incoming Document";
        TempArgument: Record "Message Argument ori" temporary;
        SetRequest: JsonObject;
        RecordObject: JsonObject;
        PrimaryKey: JsonObject;
        Fields: JsonObject;
        DataArray: JsonArray;
        ErrorText: Text;
        EntryNo: Integer;
        TypeCode: Code[20];
    begin
        // [SCENARIO] AC07: Data.Records.Set cannot write Incoming Document Data Exchange Type or Data Exchange Type rows.
        Initialize();
        TypeCode := SeedImportType();
        EntryNo := IncomingDocument.CreateIncomingDocument('BIFT-P2-AC07', '');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exchange Type", false), 'Type table writes are restricted.');

        Fields.Add('Description', 'hack');
        RecordObject.Add('fields', Fields);
        DataArray.Add(RecordObject);
        SetRequest.Add('tableName', 'Data Exchange Type');
        SetRequest.Add('data', DataArray);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Data.Records.Set", SetRequest);
        ErrorText := ReadText(TempArgument.GetResponseJson(), 'error');
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'AC07 type table status');
        LibraryAssert.IsTrue(ErrorText.Contains('cannot be written'), 'AC07 type table text');
        LibraryAssert.IsTrue(ErrorText.Contains(TypeSetHintTok), 'AC07 names Type.Set.');

        Clear(TempArgument);
        Clear(SetRequest);
        Clear(RecordObject);
        Clear(Fields);
        Clear(DataArray);
        PrimaryKey.Add('EntryNo', EntryNo);
        Fields.Add('DataExchangeType', TypeCode);
        RecordObject.Add('primaryKey', PrimaryKey);
        RecordObject.Add('fields', Fields);
        DataArray.Add(RecordObject);
        SetRequest.Add('tableName', 'Incoming Document');
        SetRequest.Add('data', DataArray);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Data.Records.Set", SetRequest);
        ErrorText := ReadText(TempArgument.GetResponseJson(), 'error');
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'AC07 field status');
        LibraryAssert.IsTrue(ErrorText.Contains('cannot be written'), 'AC07 field text');
        LibraryAssert.IsTrue(
            ReadText(TempArgument.GetResponseJson(), 'nextStep').Contains('Storage.Upload.CommitToRecord') or
            ErrorText.Contains('Storage.Upload.CommitToRecord'),
            'AC07 names CommitToRecord.');
        IncomingDocument.Get(EntryNo);
        LibraryAssert.AreEqual('', IncomingDocument."Data Exchange Type", 'AC07 leaves the field empty.');
    end;

    local procedure AssertLinkedContentServed(EntryNo: Integer; Expected: Text)
    var
        Attachment: Record "Incoming Document Attachment";
        ContentBlob: Codeunit System.Utilities."Temp Blob";
        ContentInStream: InStream;
        ReadBack: Text;
    begin
        Attachment.SetRange("Incoming Document Entry No.", EntryNo);
        LibraryAssert.AreEqual(1, Attachment.Count(), 'AC04 has one incoming attachment.');
        Attachment.FindFirst();
        LibraryAssert.IsFalse(Attachment.Content.HasValue(), 'AC04 clears local content so the read uses the storage link.');
        LibraryAssert.IsTrue(Attachment.GetContent(ContentBlob), 'AC04 GetContent serves the linked file.');
        ContentBlob.CreateInStream(ContentInStream);
        ContentInStream.ReadText(ReadBack);
        LibraryAssert.AreEqual(Expected, ReadBack, 'AC04 served bytes match the stored file.');
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

    local procedure SeedImportType() TypeCode: Code[20]
    var
        Definition: Record "Data Exch. Def";
        ExchangeType: Record "Data Exchange Type";
        TempArgument: Record "Message Argument ori" temporary;
        RequestJson: JsonObject;
    begin
        SeedDefinition(Definition, Definition.Type::"Generic Import");
        TypeCode := Definition.Code;
        RequestJson.Add('code', TypeCode);
        RequestJson.Add('dataExchDefCode', Definition.Code);
        RequestJson.Add('description', 'Phase 2 test type');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"DataExchange.Type.Set", RequestJson);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Type.Set must succeed for the fixture.');
        LibraryAssert.IsTrue(ExchangeType.Get(TypeCode), 'Fixture type exists.');
    end;

    local procedure SeedDefinition(var Definition: Record "Data Exch. Def"; DefinitionType: Enum "Data Exchange Definition Type")
    begin
        Definition.Init();
        Definition.Code := NewFixtureCode();
        Definition.Name := 'Phase 2 test';
        Definition.Type := DefinitionType;
        Definition."File Type" := Definition."File Type"::"Variable Text";
        Definition.Insert();
    end;

    local procedure NewFixtureCode(): Code[20]
    begin
        exit(CopyStr('P2' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20));
    end;

    local procedure BeginAndAppend(var UploadId: Text; FileName: Text; Content: Text)
    var
        Path: Text;
    begin
        BeginUpload(FileName, UploadId, Path);
        AppendChunk(UploadId, 1, Content);
    end;

    local procedure BeginUpload(FileName: Text; var UploadId: Text; var Path: Text)
    var
        TempArgument: Record "Message Argument ori" temporary;
        BeginReq: JsonObject;
    begin
        BeginReq.Add('storageCode', MockCodeTok);
        BeginReq.Add('fileName', FileName);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", BeginReq);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Begin should succeed.');
        UploadId := ReadDataText(TempArgument, 'uploadId');
        Path := ReadDataText(TempArgument, 'path');
    end;

    local procedure AppendChunk(UploadId: Text; SequenceNo: Integer; ContentText: Text)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Base64Convert: Codeunit "Base64 Convert";
        AppendReq: JsonObject;
    begin
        AppendReq.Add('uploadId', UploadId);
        AppendReq.Add('sequence', SequenceNo);
        AppendReq.Add('contentBase64', Base64Convert.ToBase64(ContentText));
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Append", AppendReq);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Append should succeed.');
    end;

    local procedure CommitUpload(var TempArgument: Record "Message Argument ori" temporary; UploadId: Text)
    var
        CommitReq: JsonObject;
    begin
        Clear(TempArgument);
        CommitReq.Add('uploadId', UploadId);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Commit", CommitReq);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Commit should succeed.');
    end;

    local procedure ExecuteCommit(var TempArgument: Record "Message Argument ori" temporary; UploadId: Text; TypeCode: Code[20]; Process: Boolean; Description: Text)
    var
        CommitReq: JsonObject;
    begin
        Clear(TempArgument);
        CommitReq.Add('uploadId', UploadId);
        CommitReq.Add('target', 'IncomingDocument');
        CommitReq.Add('description', Description);
        CommitReq.Add('dataExchangeType', TypeCode);
        CommitReq.Add('process', Process);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.CommitToRecord", CommitReq);
    end;

    local procedure ExecuteTypeWithRequest(var TempArgument: Record "Message Argument ori" temporary; MessageType: Enum "Message Type ori"; RequestJson: JsonObject)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
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

    local procedure ReadDataText(var TempArgument: Record "Message Argument ori" temporary; PropertyName: Text): Text
    var
        Token: JsonToken;
        DataObject: JsonObject;
    begin
        DataObject := ReadData(TempArgument.GetResponseJson());
        if DataObject.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadDataInt(var TempArgument: Record "Message Argument ori" temporary; PropertyName: Text): Integer
    var
        Token: JsonToken;
        DataObject: JsonObject;
    begin
        DataObject := ReadData(TempArgument.GetResponseJson());
        if DataObject.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsInteger());
        exit(0);
    end;

    local procedure ReadDataBool(var TempArgument: Record "Message Argument ori" temporary; PropertyName: Text): Boolean
    var
        Token: JsonToken;
        DataObject: JsonObject;
    begin
        DataObject := ReadData(TempArgument.GetResponseJson());
        if DataObject.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsBoolean());
        exit(false);
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
