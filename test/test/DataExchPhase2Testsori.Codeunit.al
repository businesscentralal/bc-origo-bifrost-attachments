namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
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

    /// <summary>Proves linked bytes reach the base CSV reader and mapper in both supported languages.</summary>
    [Test]
    procedure Scenario_AC04_LinkedCsv_ProcessReadsAndMapsExactContent()
    begin
        // Story #23, AC04 | Time: no date dependency | Risk: base-app CSV import path
        AssertIncomingCsvProcessing(1033, true);
        AssertIncomingCsvProcessing(1039, true);
    end;

    /// <summary>Proves the standard unlinked attachment processing path still maps local bytes.</summary>
    [Test]
    procedure Scenario_AC04_LocalCsv_ProcessKeepsStandardContentPath()
    begin
        // Story #23, AC04 | Time: no date dependency | Risk: unlinked attachment regression
        AssertIncomingCsvProcessing(1033, false);
        AssertIncomingCsvProcessing(1039, false);
    end;

    local procedure AssertIncomingCsvProcessing(LanguageId: Integer; Linked: Boolean)
    var
        IncomingDocument: Record "Incoming Document";
        IncomingAttachment: Record "Incoming Document Attachment";
        ExchangeType: Record "Data Exchange Type";
        DataExch: Record "Data Exch.";
        Target: Record "DataExch Test Target ori";
        Link: Record "Storage Attachment Link ori";
        TempArgument: Record "Message Argument ori" temporary;
        Fixture: Codeunit "DataExch Fixture ori";
        MockState: Codeunit "Storage Mock State";
        RequestJson: JsonObject;
        DefinitionCode: Code[20];
        UploadId: Text;
        Path: Text;
        ExpectedBase64: Text;
        FileName: Text;
        EntryNo: Integer;
        SavedLanguage: Integer;
    begin
        // [GIVEN] An isolated CSV definition maps both rows through the real base-app CSV reader.
        Initialize();
        DefinitionCode := Fixture.CreateImportDefinition(1);
        ExchangeType.Init();
        ExchangeType.Code := DefinitionCode;
        ExchangeType."Data Exch. Def. Code" := DefinitionCode;
        ExchangeType.Insert();
        FileName := 'phase2-reader-' + LowerCase(Format(CreateGuid(), 0, 4)) + '.csv';
        BeginUpload(FileName, UploadId, Path);
        AppendChunk(UploadId, 1, Fixture.TwoLineCsv(true));
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);

        // [WHEN] The public upload/link path asks the built-in incoming-document processor to run.
        if Linked then begin
            CommitUpload(TempArgument, UploadId);
            ExpectedBase64 := MockState.GetFileContent(Path);
            RequestJson.Add('storageCode', MockCodeTok);
            RequestJson.Add('path', Path);
            RequestJson.Add('fileName', FileName);
            RequestJson.Add('dataExchangeType', DefinitionCode);
            RequestJson.Add('process', true);
            ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateLinked", RequestJson);
        end else
            ExecuteCommit(TempArgument, UploadId, DefinitionCode, true, 'BIFT-P2-reader-local');
        GlobalLanguage(SavedLanguage);

        // [THEN] Prove the bytes reached the reader and mapper, rather than accepting any processing error.
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Incoming creation must succeed.');
        EntryNo := ReadDataInt(TempArgument, 'incomingDocumentEntryNo');
        IncomingDocument.Get(EntryNo);
        DataExch.SetRange("Incoming Entry No.", EntryNo);
        LibraryAssert.IsTrue(DataExch.FindFirst(), 'The real data-exchange runner must create a parsed entry.');
        LibraryAssert.AreEqual(2, Fixture.TargetCount(DataExch."Entry No."), 'The real mapper must receive both CSV rows.');
        Target.SetRange("Data Exch. No.", DataExch."Entry No.");
        Target.SetRange(Code, 'A1');
        Target.FindFirst();
        LibraryAssert.AreEqual('Alpha', Target.Name, 'Exact first-row text reaches mapping.');
        LibraryAssert.AreEqual(10.5, Target.Amount, 'Exact decimal reaches mapping in both languages.');
        LibraryAssert.IsTrue(IncomingDocument.GetMainAttachment(IncomingAttachment), 'Main attachment remains.');
        IncomingAttachment.CalcFields(Content);
        if Linked then begin
            LibraryAssert.IsFalse(IncomingAttachment.Content.HasValue(), 'Processing must not restore or persist the offloaded BLOB.');
            LibraryAssert.IsTrue(Link.Get(Database::"Incoming Document Attachment", IncomingAttachment.SystemId), 'The storage link remains.');
            LibraryAssert.AreEqual(ExpectedBase64, MockState.GetFileContent(Path), 'Processing must leave the stored bytes unchanged.');
        end else begin
            LibraryAssert.IsTrue(IncomingAttachment.Content.HasValue(), 'Unlinked content stays local.');
            LibraryAssert.IsFalse(Link.Get(Database::"Incoming Document Attachment", IncomingAttachment.SystemId), 'Unlinked processing creates no storage link.');
        end;
    end;

    /// <summary>Creates an unposted invoice through standard intermediate mapping from a linked CSV in both languages.</summary>
    [Test]
    [HandlerFunctions('ProcessingMessageHandler')]
    procedure Scenario_AC06_LinkedCsv_CreatesPurchaseInvoice()
    begin
        // Story #23, AC06 | Time: standard unposted invoice dates | Risk: base-app purchase mapping
        AssertPurchaseInvoiceProcessing(1033);
        AssertPurchaseInvoiceProcessing(1039);
    end;

    local procedure AssertPurchaseInvoiceProcessing(LanguageId: Integer)
    var
        Vendor: Record Vendor;
        GeneralBusinessGroup: Record "Gen. Business Posting Group";
        VendorPostingGroup: Record "Vendor Posting Group";
        VatBusinessGroup: Record "VAT Business Posting Group";
        PurchaseHeader: Record "Purchase Header";
        IncomingDocument: Record "Incoming Document";
        ExchangeType: Record "Data Exchange Type";
        ColumnDefinition: Record "Data Exch. Column Def";
        Mapping: Record "Data Exch. Mapping";
        FieldMapping: Record "Data Exch. Field Mapping";
        TempArgument: Record "Message Argument ori" temporary;
        Fixture: Codeunit "DataExch Fixture ori";
        RequestJson: JsonObject;
        CreatedDocument: JsonObject;
        DataObject: JsonObject;
        Token: JsonToken;
        DefinitionCode: Code[20];
        UploadId: Text;
        Path: Text;
        FileName: Text;
        Csv: Text;
        EntryNo: Integer;
        SavedLanguage: Integer;
    begin
        // [GIVEN] Self-created vendor and a standard CSV-to-purchase-header intermediate mapping.
        Initialize();
        GeneralBusinessGroup.Code := NewFixtureCode();
        GeneralBusinessGroup.Insert();
        VendorPostingGroup.Code := NewFixtureCode();
        VendorPostingGroup.Insert();
        VatBusinessGroup.Code := NewFixtureCode();
        VatBusinessGroup.Insert();
        Vendor.Init();
        Vendor."No." := NewFixtureCode();
        Vendor.Name := 'BIFT-P2 owned invoice vendor';
        Vendor."Gen. Bus. Posting Group" := GeneralBusinessGroup.Code;
        Vendor."Vendor Posting Group" := VendorPostingGroup.Code;
        Vendor."VAT Bus. Posting Group" := VatBusinessGroup.Code;
        Vendor.Insert(true);
        DefinitionCode := Fixture.CreateImportDefinition(0);
        ColumnDefinition.Get(DefinitionCode, 'LINES', 3);
        ColumnDefinition."Data Type" := ColumnDefinition."Data Type"::Text;
        ColumnDefinition.Modify();
        Mapping.SetRange("Data Exch. Def Code", DefinitionCode);
        Mapping.DeleteAll();
        FieldMapping.SetRange("Data Exch. Def Code", DefinitionCode);
        FieldMapping.DeleteAll();
        Mapping.Init();
        Mapping."Data Exch. Def Code" := DefinitionCode;
        Mapping."Data Exch. Line Def Code" := 'LINES';
        Mapping."Table ID" := Database::"Intermediate Data Import";
        Mapping."Use as Intermediate Table" := true;
        Mapping."Mapping Codeunit" := Codeunit::"Map DataExch To Intermediate";
        Mapping."Post-Mapping Codeunit" := Codeunit::"Map Incoming Doc to Purch Doc";
        Mapping.Insert();
        AddPurchaseFieldMapping(DefinitionCode, 1, PurchaseHeader.FieldNo("Document Type"));
        AddPurchaseFieldMapping(DefinitionCode, 2, PurchaseHeader.FieldNo("Buy-from Vendor No."));
        AddPurchaseFieldMapping(DefinitionCode, 3, PurchaseHeader.FieldNo("Currency Code"));
        ExchangeType.Init();
        ExchangeType.Code := DefinitionCode;
        ExchangeType."Data Exch. Def. Code" := DefinitionCode;
        ExchangeType.Insert();
        FileName := 'phase2-invoice-' + LowerCase(Format(CreateGuid(), 0, 4)) + '.csv';
        Csv := Format(PurchaseHeader."Document Type"::Invoice.AsInteger(), 0, 9) + ',' + Vendor."No." + ', ';
        // Preserve a blank base-currency column: the base CSV reader omits empty fields entirely.
        BeginUpload(FileName, UploadId, Path);
        AppendChunk(UploadId, 1, Csv);
        CommitUpload(TempArgument, UploadId);
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('path', Path);
        RequestJson.Add('fileName', FileName);
        RequestJson.Add('dataExchangeType', DefinitionCode);
        RequestJson.Add('process', true);

        // [WHEN] The real message runs the built-in incoming-document processing chain.
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateLinked", RequestJson);
        GlobalLanguage(SavedLanguage);

        // [THEN] Read the actual unposted invoice; response identifiers must identify that invoice.
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Creation remains Success.');
        EntryNo := ReadDataInt(TempArgument, 'incomingDocumentEntryNo');
        IncomingDocument.Get(EntryNo);
        DataObject := ReadData(TempArgument.GetResponseJson());
        LibraryAssert.IsTrue(ReadDataBool(TempArgument, 'processed'), 'Standard mapping must create the purchase invoice. ' + Format(DataObject.GetArray('processErrors')));
        DataObject := ReadData(TempArgument.GetResponseJson());
        LibraryAssert.IsTrue(DataObject.Get('createdDocument', Token), 'Return the created invoice.');
        CreatedDocument := Token.AsObject();
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, ReadText(CreatedDocument, 'no'));
        LibraryAssert.AreEqual(Vendor."No.", PurchaseHeader."Buy-from Vendor No.", 'The self-created vendor is used.');
        LibraryAssert.AreEqual(EntryNo, PurchaseHeader."Incoming Document Entry No.", 'Invoice links to the incoming document.');
        LibraryAssert.AreEqual(Format(PurchaseHeader.SystemId, 0, 4), ReadText(CreatedDocument, 'systemId'), 'Response identifies the actual purchase invoice.');
    end;

    local procedure AddPurchaseFieldMapping(DefinitionCode: Code[20]; ColumnNo: Integer; TargetFieldId: Integer)
    var
        FieldMapping: Record "Data Exch. Field Mapping";
    begin
        FieldMapping.Init();
        FieldMapping."Data Exch. Def Code" := DefinitionCode;
        FieldMapping."Data Exch. Line Def Code" := 'LINES';
        FieldMapping."Table ID" := Database::"Intermediate Data Import";
        FieldMapping."Column No." := ColumnNo;
        FieldMapping."Target Table ID" := Database::"Purchase Header";
        FieldMapping."Target Field ID" := TargetFieldId;
        FieldMapping.Insert();
    end;

    /// <summary>Handles the standard base-app document-created notification during native processing.</summary>
    [MessageHandler]
    procedure ProcessingMessageHandler(Message: Text[1024])
    begin
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
