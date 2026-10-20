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
        AssertProblem(Response, 'InvalidParameter', 'dataExchDefCode');
        LibraryAssert.AreEqual(DefCode, Fixture.ReadText(Response, 'received'), 'Definition context uses its own parameter.');
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
        LibraryAssert.AreEqual(' ', Fixture.ReadText(Fixture.Data(Response), 'documentType'), 'Blank document type uses the enum name, not ordinal zero.');
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
        LibraryAssert.AreEqual(' ', Fixture.ReadText(Fixture.Data(Response), 'documentType'), 'Return the blank document type enum name.');
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
