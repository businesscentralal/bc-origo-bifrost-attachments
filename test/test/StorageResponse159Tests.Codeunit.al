namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.TestLibraries.Utilities;

/// <summary>Issue 159: public response contracts and independently collected request problems in both languages.</summary>
codeunit 96258 "Storage Response159 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "DataExch Fixture ori";
        LibraryAssert: Codeunit "Library Assert";

    /// <summary>DefinitionCollects: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure DefinitionCollects_1033()
    begin
        CheckDefinitionCollects(1033);
    end;

    /// <summary>DefinitionCollects: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure DefinitionCollects_1039()
    begin
        CheckDefinitionCollects(1039);
    end;

    local procedure CheckDefinitionCollects(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('code', 12345);
        Request.Add('inline', 'yes');
        Response := Dispatch("Message Type ori"::"DataExchange.Definition.Export", Request, LanguageId);
        AssertProblem(Response, 'InvalidParameterFormat', 'code');
        AssertProblem(Response, 'InvalidParameterFormat', 'inline');
        LibraryAssert.AreEqual(2, Fixture.ReadArray(Response, 'errors').Count(), 'Exactly the two independently invalid fields.');
    end;

    /// <summary>CodeLength: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure CodeLength_1033()
    begin
        CheckCodeLength(1033);
    end;

    /// <summary>CodeLength: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure CodeLength_1039()
    begin
        CheckCodeLength(1039);
    end;

    local procedure CheckCodeLength(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('code', PadStr('', 21, 'X'));
        Response := Dispatch("Message Type ori"::"DataExchange.Definition.Export", Request, LanguageId);
        AssertProblem(Response, 'InvalidParameterFormat', 'code');
        LibraryAssert.IsFalse(Response.Contains('errors'), 'A single error retains the single-error envelope.');
        Request.Add('dataExchDefCode', 'X159');
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Set", Request, LanguageId);
        AssertProblem(Response, 'InvalidParameterFormat', 'code');
    end;

    /// <summary>ExportConflict: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure ExportConflict_1033()
    begin
        CheckExportConflict(1033);
    end;

    /// <summary>ExportConflict: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure ExportConflict_1039()
    begin
        CheckExportConflict(1039);
    end;

    local procedure CheckExportConflict(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        RecordIds: JsonArray;
    begin
        Request.Add('dataExchDefCode', 'X159UNKNOWN');
        Request.Add('tableView', 'WHERE(No.=FILTER(X159))');
        RecordIds.Add(Format(CreateGuid(), 0, 4));
        Request.Add('recordIds', RecordIds);
        Request.Add('inline', true);
        Response := Dispatch("Message Type ori"::"DataExchange.Export.Run", Request, LanguageId);
        AssertProblem(Response, 'InvalidParameter', 'tableView');
    end;

    /// <summary>InvalidSourceTarget: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure InvalidSourceTarget_1033()
    begin
        CheckInvalidSourceTarget(1033);
    end;

    /// <summary>InvalidSourceTarget: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure InvalidSourceTarget_1039()
    begin
        CheckInvalidSourceTarget(1039);
    end;

    local procedure CheckInvalidSourceTarget(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('sourceTarget', 'Foo');
        Response := Dispatch("Message Type ori"::"Storage.Attachment.CreateForRecord", Request, LanguageId);
        AssertProblem(Response, 'InvalidParameter', 'sourceTarget');
        AssertProblem(Response, 'MissingParameter', 'sourceSystemId');
    end;

    /// <summary>EntryDefinition: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure EntryDefinition_1033()
    begin
        CheckEntryDefinition(1033);
    end;

    /// <summary>EntryDefinition: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure EntryDefinition_1039()
    begin
        CheckEntryDefinition(1039);
    end;

    local procedure CheckEntryDefinition(LanguageId: Integer)
    var
        DataExch: Record "Data Exch.";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        DefCode := Fixture.CreateExportDefinition();
        DataExch.Init();
        DataExch."Data Exch. Def Code" := DefCode;
        DataExch.Insert(true);
        Request.Add('entryNo', DataExch."Entry No.");
        Response := Dispatch("Message Type ori"::"DataExchange.Entry.Process", Request, LanguageId);
        AssertProblem(Response, 'InvalidParameter', 'entryNo');
        LibraryAssert.AreEqual(Format(DataExch."Entry No.", 0, 9), Fixture.ReadText(Response, 'received'), 'The definition refusal identifies the selected entry.');
    end;

    /// <summary>EntryMapping: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure EntryMapping_1033()
    begin
        CheckEntryMapping(1033);
    end;

    /// <summary>EntryMapping: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure EntryMapping_1039()
    begin
        CheckEntryMapping(1039);
    end;

    local procedure CheckEntryMapping(LanguageId: Integer)
    var
        DataExch: Record "Data Exch.";
        Mapping: Record "Data Exch. Mapping";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        DefCode := Fixture.CreateImportDefinition(0);
        Mapping.SetRange("Data Exch. Def Code", DefCode);
        Mapping.DeleteAll();
        DataExch.Init();
        DataExch."Data Exch. Def Code" := DefCode;
        DataExch.Insert(true);
        Request.Add('entryNo', DataExch."Entry No.");
        Response := Dispatch("Message Type ori"::"DataExchange.Entry.Process", Request, LanguageId);
        LibraryAssert.AreEqual('entryNo', Fixture.ReadText(Response, 'parameter'), 'Mapping refusal refers to the selected entry.');
        LibraryAssert.AreEqual(Format(DataExch."Entry No.", 0, 9), Fixture.ReadText(Response, 'received'), 'received matches entryNo.');
    end;

    /// <summary>StoredDefinition: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure StoredDefinition_1033()
    begin
        CheckStoredDefinition(1033);
    end;

    /// <summary>StoredDefinition: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure StoredDefinition_1039()
    begin
        CheckStoredDefinition(1039);
    end;

    local procedure CheckStoredDefinition(LanguageId: Integer)
    var
        MockState: Codeunit "Storage Mock State";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Fixture.InitializeStorage();
        MockState.PutFile('x159/invalid.xml', Fixture.Encode('not XML'));
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'x159/invalid.xml');
        Response := Dispatch("Message Type ori"::"DataExchange.Definition.Import", Request, LanguageId);
        AssertProblem(Response, 'InvalidParameterFormat', 'path');
        LibraryAssert.IsTrue(MockState.HasFile('x159/invalid.xml'), 'Invalid input is read-only.');
    end;

    /// <summary>LinkedFileName: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure LinkedFileName_1033()
    begin
        CheckLinkedFileName(1033);
    end;

    /// <summary>LinkedFileName: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure LinkedFileName_1039()
    begin
        CheckLinkedFileName(1039);
    end;

    local procedure CheckLinkedFileName(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        Detail: JsonObject;
    begin
        Fixture.InitializeStorage();
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'x159/input.txt');
        Request.Add('target', 'DocumentAttachment');
        Request.Add('tableId', Database::Customer);
        Request.Add('no', 'X159');
        Request.Add('fileName', 'folder/file.txt');
        Response := Dispatch("Message Type ori"::"Storage.Attachment.CreateLinked", Request, LanguageId);
        Detail := FindProblem(Response, 'fileName');
        LibraryAssert.AreEqual('InvalidParameter', Fixture.ReadText(Detail, 'code'), 'File names must not contain directories.');
        LibraryAssert.IsTrue(Fixture.ReadText(Detail, 'nextStep').Contains('INV-001.pdf'), 'The recovery step gives a file-name example.');
        LibraryAssert.IsFalse(Fixture.ReadText(Detail, 'nextStep').Contains('invoices/'), 'The recovery step must not suggest a path.');
    end;

    /// <summary>MissingImportSource: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure MissingImportSource_1033()
    begin
        CheckMissingImportSource(1033);
    end;

    /// <summary>MissingImportSource: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure MissingImportSource_1039()
    begin
        CheckMissingImportSource(1039);
    end;

    local procedure CheckMissingImportSource(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        Detail: JsonObject;
    begin
        Response := Dispatch("Message Type ori"::"DataExchange.Import.Run", Request, LanguageId);
        Detail := FindProblem(Response, 'contentBase64');
        LibraryAssert.AreEqual('MissingParameter', Fixture.ReadText(Detail, 'code'), 'Missing content must be actionable.');
        LibraryAssert.IsTrue(Fixture.ReadText(Detail, 'nextStep').Contains('contentBase64'), 'The next step includes the inline alternative.');
    end;

    /// <summary>PaymentNoDuplicate: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure PaymentNoDuplicate_1033()
    begin
        CheckPaymentNoDuplicate(1033);
    end;

    /// <summary>PaymentNoDuplicate: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure PaymentNoDuplicate_1039()
    begin
        CheckPaymentNoDuplicate(1039);
    end;

    local procedure CheckPaymentNoDuplicate(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('journalTemplate', 'X159');
        Request.Add('journalBatch', 'X159');
        Request.Add('path', 'x159/a.txt');
        Request.Add('folderPath', 'x159');
        Response := Dispatch("Message Type ori"::"DataExchange.PaymentExport.Run", Request, LanguageId);
        AssertProblem(Response, 'InvalidParameter', 'folderPath');
        AssertProblem(Response, 'MissingParameter', 'storageCode');
        LibraryAssert.AreEqual(2, Fixture.ReadArray(Response, 'errors').Count(), 'One conflict and one missing connection, without duplicate storageCode errors.');
    end;

    /// <summary>MissingFile: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure MissingFile_1033()
    begin
        CheckMissingFile(1033);
    end;

    /// <summary>MissingFile: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure MissingFile_1039()
    begin
        CheckMissingFile(1039);
    end;

    local procedure CheckMissingFile(LanguageId: Integer)
    var
        StorageSetup: Record "Storage Setup ori";
        Request: JsonObject;
        Response: JsonObject;
        Written: Text;
    begin
        Fixture.InitializeStorage();
        StorageSetup.Get(Fixture.StorageCode());
        StorageSetup."Base Path" := 'private-account-base';
        StorageSetup.Modify();
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'x159/missing.txt');
        Response := Dispatch("Message Type ori"::"Storage.File.Get", Request, LanguageId);
        AssertProblem(Response, 'RecordNotFound', 'path');
        LibraryAssert.AreEqual('x159/missing.txt', Fixture.ReadText(Response, 'received'), 'Only the requested relative path is echoed.');
        LibraryAssert.AreNotEqual('', Fixture.ReadText(Response, 'nextStep'), 'A missing file gives a recovery step.');
        Response.WriteTo(Written);
        LibraryAssert.IsFalse(Written.Contains('private-account-base'), 'Never expose the account base path.');
        if LanguageId = 1039 then
            LibraryAssert.IsTrue(Fixture.ReadText(Response, 'error').Contains('fannst ekki'), 'The refusal is translated in Icelandic.')
        else
            LibraryAssert.IsTrue(Fixture.ReadText(Response, 'error').Contains('was not found'), 'The refusal is English in 1033.');
    end;

    /// <summary>UniformHeader: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure UniformHeader_1033()
    begin
        CheckUniformHeader(1033);
    end;

    /// <summary>UniformHeader: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure UniformHeader_1039()
    begin
        CheckUniformHeader(1039);
    end;

    local procedure CheckUniformHeader(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        DefCode := Fixture.CreateImportDefinition(0);
        Request.Add('code', DefCode);
        Response := Dispatch("Message Type ori"::"DataExchange.Definition.Export", Request, LanguageId);
        AssertEnvelope(Response);
        LibraryAssert.AreEqual(DefCode, Fixture.ReadText(Fixture.Data(Response), 'code'), 'Header is under data.');
        LibraryAssert.IsFalse(Response.Contains('code'), 'No flat duplicate code.');
        Response := Dispatch("Message Type ori"::"DataExchange.Definition.Delete", Request, LanguageId);
        AssertEnvelope(Response);
        LibraryAssert.AreEqual(DefCode, Fixture.ReadText(Fixture.Data(Response), 'code'), 'Delete code is under data.');
    end;

    /// <summary>TypeSetEnvelope: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure TypeSetEnvelope_1033()
    begin
        CheckTypeSetEnvelope(1033);
    end;

    /// <summary>TypeSetEnvelope: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure TypeSetEnvelope_1039()
    begin
        CheckTypeSetEnvelope(1039);
    end;

    local procedure CheckTypeSetEnvelope(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        DefCode := Fixture.CreateImportDefinition(0);
        Request.Add('code', Fixture.NewCode('T159'));
        Request.Add('dataExchDefCode', DefCode);
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Set", Request, LanguageId);
        AssertEnvelope(Response);
        LibraryAssert.AreEqual(DefCode, Fixture.ReadText(Fixture.Data(Response), 'dataExchDefCode'), 'Type reference is under data.');
        LibraryAssert.IsFalse(Response.Contains('dataExchDefCode'), 'No flat duplicate reference.');
    end;

    /// <summary>DocumentTypeName: the public message contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure DocumentTypeName_1033()
    begin
        CheckDocumentTypeName(1033);
    end;

    /// <summary>DocumentTypeName: the public message contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure DocumentTypeName_1039()
    begin
        CheckDocumentTypeName(1039);
    end;

    local procedure CheckDocumentTypeName(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        CustomerNos: List of [Code[20]];
    begin
        Fixture.InitializeStorage();
        CustomerNos := Fixture.CreateCustomers(1, 'X159');
        Request.Add('tableId', Database::Customer);
        Request.Add('no', CustomerNos.Get(1));
        Request.Add('fileName', 'x159.txt');
        Request.Add('contentBase64', Fixture.Encode('owned X159 content'));
        Response := Dispatch("Message Type ori"::"Storage.Attachment.CreateForRecord", Request, LanguageId);
        AssertEnvelope(Response);
        LibraryAssert.AreEqual('Quote', Fixture.ReadText(Fixture.Data(Response), 'documentType'), 'The stored document type uses its enum name, not ordinal zero.');
    end;

    /// <summary>WarningObjects uses the same response contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure WarningObjects_1033()
    begin
        CheckWarningObjects(1033);
    end;

    /// <summary>WarningObjects uses the same response contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure WarningObjects_1039()
    begin
        CheckWarningObjects(1039);
    end;

    /// <summary>UploadDocumentType uses the same response contract in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure UploadDocumentType_1033()
    begin
        CheckUploadDocumentType(1033);
    end;

    /// <summary>UploadDocumentType uses the same response contract in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure UploadDocumentType_1039()
    begin
        CheckUploadDocumentType(1039);
    end;

    local procedure CheckWarningObjects(LanguageId: Integer)
    var
        DataExch: Record "Data Exch.";
        Mapping: Record "Data Exch. Mapping";
        Request: JsonObject;
        Response: JsonObject;
        Warning: JsonObject;
        Warnings: JsonArray;
        Token: JsonToken;
        DefCode: Code[20];
    begin
        DefCode := Fixture.CreateImportDefinition(0);
        Mapping.SetRange("Data Exch. Def Code", DefCode);
        Mapping.FindFirst();
        Mapping."Mapping Codeunit" := 0;
        Mapping.Modify();
        DataExch.Init();
        DataExch."Data Exch. Def Code" := DefCode;
        DataExch.Insert(true);
        Request.Add('entryNo', DataExch."Entry No.");
        Request.Add('mappingLineDef', Mapping."Data Exch. Line Def Code");
        Response := Dispatch("Message Type ori"::"DataExchange.Entry.Process", Request, LanguageId);
        AssertEnvelope(Response);
        Warnings := Fixture.ReadArray(Fixture.Data(Response), 'warnings');
        LibraryAssert.AreEqual(1, Warnings.Count(), 'One mapping without a processing codeunit.');
        Warnings.Get(0, Token);
        LibraryAssert.IsTrue(Token.IsObject(), 'Warnings are objects, never bare strings.');
        Warning := Token.AsObject();
        LibraryAssert.AreEqual('NoMappingCodeunit', Fixture.ReadText(Warning, 'code'), 'Stable warning code.');
        LibraryAssert.AreNotEqual('', Fixture.ReadText(Warning, 'message'), 'Localized warning message.');
        LibraryAssert.AreEqual(2, Warning.Keys().Count(), 'Exactly code and message.');
    end;

    local procedure CheckUploadDocumentType(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        UploadId: Text;
        CustomerNos: List of [Code[20]];
    begin
        Fixture.InitializeStorage();
        CustomerNos := Fixture.CreateCustomers(1, 'X159UPLOAD');
        Request.Add('fileName', 'x159-upload.txt');
        Response := Dispatch("Message Type ori"::"Storage.Upload.Begin", Request, LanguageId);
        AssertEnvelope(Response);
        UploadId := Fixture.ReadText(Fixture.Data(Response), 'uploadId');
        Clear(Request);
        Request.Add('uploadId', UploadId);
        Request.Add('sequence', 1);
        Request.Add('contentBase64', Fixture.Encode('owned X159 upload'));
        Response := Dispatch("Message Type ori"::"Storage.Upload.Append", Request, LanguageId);
        AssertEnvelope(Response);
        Clear(Request);
        Request.Add('uploadId', UploadId);
        Request.Add('tableId', Database::Customer);
        Request.Add('no', CustomerNos.Get(1));
        Response := Dispatch("Message Type ori"::"Storage.Upload.CommitToRecord", Request, LanguageId);
        AssertEnvelope(Response);
        LibraryAssert.AreEqual('Quote', Fixture.ReadText(Fixture.Data(Response), 'documentType'), 'Return the stored document type enum name.');
    end;

    /// <summary>Issue 175 ACF2_MissingFileName_SingleError: public queued response in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_ACF2_MissingFileName_SingleError_1033()
    begin
        CheckMissingLinkedFileName(1033);
    end;

    /// <summary>Issue 175 ACF2_MissingFileName_SingleError: public queued response in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_ACF2_MissingFileName_SingleError_1039()
    begin
        CheckMissingLinkedFileName(1039);
    end;

    /// <summary>Issue 175 ACF3_NestedProblems_HaveNextStep: public queued response in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_ACF3_NestedProblems_HaveNextStep_1033()
    begin
        CheckRecordProblemDetails(1033);
    end;

    /// <summary>Issue 175 ACF3_NestedProblems_HaveNextStep: public queued response in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_ACF3_NestedProblems_HaveNextStep_1039()
    begin
        CheckRecordProblemDetails(1039);
    end;

    local procedure CheckMissingLinkedFileName(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        NullName: JsonValue;
        InvalidName: JsonObject;
    begin
        Fixture.InitializeStorage();
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'x175/source.txt');
        Response := Dispatch("Message Type ori"::"Storage.Attachment.CreateLinked", Request, LanguageId);
        AssertSingleMissingFileName(Response);
        NullName.SetValueToNull();
        Request.Add('fileName', NullName);
        Response := Dispatch("Message Type ori"::"Storage.Attachment.CreateLinked", Request, LanguageId);
        AssertSingleMissingFileName(Response);
        Request.Replace('fileName', '');
        Response := Dispatch("Message Type ori"::"Storage.Attachment.CreateLinked", Request, LanguageId);
        AssertSingleMissingFileName(Response);
        Request.Replace('fileName', InvalidName);
        Response := Dispatch("Message Type ori"::"Storage.Attachment.CreateLinked", Request, LanguageId);
        AssertProblem(Response, 'InvalidParameterFormat', 'fileName');
        LibraryAssert.IsFalse(Response.Contains('errors'), 'An invalid JSON fileName reports only its reader error.');
    end;

    local procedure AssertSingleMissingFileName(Response: JsonObject)
    begin
        AssertProblem(Response, 'MissingParameter', 'fileName');
        LibraryAssert.IsFalse(Response.Contains('errors'), 'A missing fileName is one flat MissingParameter, without a format duplicate.');
        LibraryAssert.IsTrue(Response.Contains('received'), 'The error describes the missing value.');
        LibraryAssert.AreNotEqual('', Fixture.ReadText(Response, 'nextStep'), 'The error gives a recovery step.');
    end;

    local procedure CheckRecordProblemDetails(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        Problem: JsonObject;
        InvalidName: JsonObject;
    begin
        // [SCENARIO] Missing table and source are independent, actionable problems.
        Response := Dispatch("Message Type ori"::"Storage.Attachment.CreateForRecord", Request, LanguageId);
        LibraryAssert.AreEqual(2, Fixture.ReadArray(Response, 'errors').Count(), 'The request has two independent problems.');
        AssertAllNextSteps(Response);
        Problem := FindProblem(Response, 'tableId');
        LibraryAssert.IsTrue(Problem.Contains('received'), 'Missing tableId carries received just like the other required parameters.');
        LibraryAssert.AreNotEqual('', Fixture.ReadText(Problem, 'received'), 'The missing table is explicitly described.');

        // [SCENARIO] Invalid source target, missing source id and malformed fileName all give a next step.
        Request.Add('sourceTarget', 'UnknownAttachment');
        Request.Add('fileName', InvalidName);
        Response := Dispatch("Message Type ori"::"Storage.Attachment.CreateForRecord", Request, LanguageId);
        AssertProblem(Response, 'InvalidParameter', 'sourceTarget');
        AssertProblem(Response, 'MissingParameter', 'sourceSystemId');
        AssertProblem(Response, 'InvalidParameterFormat', 'fileName');
        AssertAllNextSteps(Response);

        // [SCENARIO] A missing record key and conflicting inline sources are independently actionable.
        Clear(Request);
        Request.Add('tableId', Database::Customer);
        Request.Add('content', 'eA==');
        Request.Add('contentBase64', 'eA==');
        Response := Dispatch("Message Type ori"::"Storage.Attachment.CreateForRecord", Request, LanguageId);
        AssertProblem(Response, 'MissingParameter', 'no');
        AssertProblem(Response, 'InvalidParameter', 'content');
        AssertAllNextSteps(Response);
    end;

    local procedure AssertAllNextSteps(Response: JsonObject)
    var
        Token: JsonToken;
    begin
        foreach Token in Fixture.ReadArray(Response, 'errors') do
            LibraryAssert.AreNotEqual('', Fixture.ReadText(Token.AsObject(), 'nextStep'), 'Every nested problem must explain how to retry.');
    end;

    /// <summary>Issue 175 F4: CreateForRecord examples use declared source parameters.</summary>
    [Test]
    procedure Scenario_ACF4_Examples_NoTargetParameter()
    var
        Contract: Interface "Msg Contract ori";
        Examples: JsonArray;
        ExampleToken: JsonToken;
        RequestToken: JsonToken;
        DataToken: JsonToken;
        Request: JsonObject;
    begin
        Contract := "Message Type ori"::"Storage.Attachment.CreateForRecord";
        LibraryAssert.IsTrue(Contract.GetExamples(Examples), 'The type publishes examples.');
        LibraryAssert.AreNotEqual(0, Examples.Count(), 'The check must exercise actual examples.');
        foreach ExampleToken in Examples do begin
            LibraryAssert.IsTrue(ExampleToken.AsObject().Get('request', RequestToken), 'Every example has a request.');
            if RequestToken.IsObject() then
                Request := RequestToken.AsObject()
            else
                LibraryAssert.IsTrue(Request.ReadFrom(RequestToken.AsValue().AsText()), 'The example request is JSON.');
            LibraryAssert.IsTrue(Request.Get('data', DataToken), 'Every example carries request data.');
            LibraryAssert.IsFalse(DataToken.AsObject().Contains('target'), 'CreateForRecord never accepts a destination target; sourceTarget selects only an existing source attachment.');
        end;
    end;

    /// <summary>Issue 175 F6a: account-prefixed provider metadata stays private in LCID 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_ACF6a_Lists_HideAccountPath_1033()
    begin
        CheckListingPrivacy(1033);
    end;

    /// <summary>Issue 175 F6a: account-prefixed provider metadata stays private in LCID 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_ACF6a_Lists_HideAccountPath_1039()
    begin
        CheckListingPrivacy(1039);
    end;

    local procedure CheckListingPrivacy(LanguageId: Integer)
    var
        StorageSetup: Record "Storage Setup ori";
        File: Record "Storage MCP File ori";
        StorageCode: Code[20];
    begin
        // [GIVEN] This test owns a connector, its account base and two explicit provider files.
        StorageCode := CopyStr('X175LIST' + Format(LanguageId, 0, 9), 1, MaxStrLen(StorageCode));
        StorageSetup.Init();
        StorageSetup.Code := StorageCode;
        StorageSetup.Description := 'Owned issue 175 listing fixture';
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::"MCP Fixture";
        StorageSetup."Base Path" := 'x175-private-account';
        StorageSetup.Enabled := true;
        StorageSetup.Insert();
        File.Init();
        File."Storage Code" := StorageCode;
        File.Path := 'x175-private-account/root.txt';
        File.Insert();
        File.Path := 'x175-private-account/nested/child.txt';
        File.Insert();

        // [WHEN/THEN] Both root and nested file listings expose only connection-relative metadata.
        AssertPrivateListing("Message Type ori"::"Storage.File.List", StorageCode, '', '', 'root.txt', LanguageId);
        AssertPrivateListing("Message Type ori"::"Storage.File.List", StorageCode, '/nested/', 'nested', 'child.txt', LanguageId);
        // The same serializer serves directories; infer this directory from the self-created nested file.
        AssertPrivateListing("Message Type ori"::"Storage.Directory.List", StorageCode, '', '', 'nested', LanguageId);

        File.SetRange("Storage Code", StorageCode);
        File.DeleteAll();
        StorageSetup.Delete();
    end;

    local procedure AssertPrivateListing(MessageType: Enum "Message Type ori"; StorageCode: Code[20]; RequestPath: Text; ExpectedParent: Text; ExpectedName: Text; LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        Entry: JsonObject;
        Entries: JsonArray;
        Token: JsonToken;
        ResponseText: Text;
    begin
        Request.Add('storageCode', StorageCode);
        Request.Add('path', RequestPath);
        Response := Dispatch(MessageType, Request, LanguageId);
        AssertEnvelope(Response);
        LibraryAssert.AreEqual(ExpectedParent, Fixture.ReadText(Fixture.Data(Response), 'path'), 'The top-level path is connection-relative.');
        Entries := Fixture.ReadArray(Fixture.Data(Response), 'entries');
        LibraryAssert.AreEqual(1, Entries.Count(), 'The fixture has one direct child: ' + ExpectedParent + '/' + ExpectedName);
        Entries.Get(0, Token);
        Entry := Token.AsObject();
        LibraryAssert.AreEqual(ExpectedParent, Fixture.ReadText(Entry, 'parentDirectory'), 'The parent directory never includes the account base path.');
        LibraryAssert.AreEqual(ExpectedName, Fixture.ReadText(Entry, 'name'), 'Only the leaf entry name is public.');
        Response.WriteTo(ResponseText);
        LibraryAssert.IsFalse(ResponseText.Contains('x175-private-account'), 'No field may expose the provider account prefix.');
    end;

    local procedure AssertEnvelope(Response: JsonObject)
    var
        Token: JsonToken;
    begin
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Every success uses Success. ' + Fixture.ReadText(Response, 'error'));
        LibraryAssert.IsTrue(Response.Get('data', Token), 'Every success contains data.');
        LibraryAssert.IsTrue(Token.IsObject(), 'The payload is an object.');
        LibraryAssert.AreEqual(2, Response.Keys().Count(), 'Exactly status and data at the top level.');
    end;

    local procedure FindProblem(Response: JsonObject; ParameterName: Text): JsonObject
    var
        Token: JsonToken;
        Problems: JsonArray;
    begin
        LibraryAssert.AreEqual('Error', Fixture.ReadText(Response, 'status'), 'The request must fail.');
        if Response.Get('errors', Token) then begin
            Problems := Token.AsArray();
            foreach Token in Problems do
                if Fixture.ReadText(Token.AsObject(), 'parameter') = ParameterName then
                    exit(Token.AsObject());
            LibraryAssert.Fail('Missing collected error on ' + ParameterName);
        end;
        LibraryAssert.AreEqual(ParameterName, Fixture.ReadText(Response, 'parameter'), 'The single error names the parameter.');
        exit(Response);
    end;

    local procedure AssertProblem(Response: JsonObject; ExpectedCode: Text; ParameterName: Text)
    var
        Detail: JsonObject;
    begin
        Detail := FindProblem(Response, ParameterName);
        LibraryAssert.AreEqual(ExpectedCode, Fixture.ReadText(Detail, 'code'), 'Stable refusal code on ' + ParameterName);
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Request: JsonObject; LanguageId: Integer) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseText: Text;
        ContentType: Text[100];
        TaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        // The queued public route applies the requested LCID; Execute uses the setup default.
        Commit();
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, TaskId, LanguageId, MessageId, ResponseContent, ContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        LibraryAssert.IsTrue(Response.ReadFrom(ResponseText), 'The public dispatcher returns JSON.');
    end;
}
