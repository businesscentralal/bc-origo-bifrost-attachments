namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Issue 156: localized format refusals through the real queue and unchanged import state.</summary>
codeunit 96256 "DataExch Format Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "DataExch Fixture ori";
        LibraryAssert: Codeunit "Library Assert";

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure XmlInline_RefusesInBothLanguages()
    begin
        CheckImportRefusal(1033, false, false);
        CheckImportRefusal(1039, false, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure XmlStorage_RefusesInBothLanguages()
    begin
        CheckImportRefusal(1033, true, false);
        CheckImportRefusal(1039, true, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure BinaryCsvInline_RefusesInBothLanguages()
    begin
        CheckImportRefusal(1033, false, true);
        CheckImportRefusal(1039, false, true);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure BinaryCsvStorage_RefusesInBothLanguages()
    begin
        CheckImportRefusal(1033, true, true);
        CheckImportRefusal(1039, true, true);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure DefinitionInline_RefusesInBothLanguages()
    begin
        CheckDefinitionRefusal(1033, false);
        CheckDefinitionRefusal(1039, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure DefinitionStorage_RefusesInBothLanguages()
    begin
        CheckDefinitionRefusal(1033, true);
        CheckDefinitionRefusal(1039, true);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure UploadXml_RefusesAndKeepsChunks()
    begin
        CheckUploadRefusal(1033, false, false);
        CheckUploadRefusal(1039, false, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure UploadBinaryCsv_RefusesAndKeepsChunks()
    begin
        CheckUploadRefusal(1033, true, false);
        CheckUploadRefusal(1039, true, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure DefinitionUpload_RefusesAndKeepsChunks()
    begin
        CheckUploadRefusal(1033, false, true);
        CheckUploadRefusal(1039, false, true);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure MissingStoredFile_RemainsBusinessCentralError()
    begin
        CheckReadFailure(1033, "Message Type ori"::"DataExchange.Import.Run");
        CheckReadFailure(1039, "Message Type ori"::"DataExchange.Import.Run");
        CheckReadFailure(1033, "Message Type ori"::"DataExchange.Definition.Import");
        CheckReadFailure(1039, "Message Type ori"::"DataExchange.Definition.Import");
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure PostwriteReaderFailure_RetainsRollback()
    begin
        CheckReaderRollback(1033);
        CheckReaderRollback(1039);
    end;

    local procedure CheckReaderRollback(LanguageId: Integer)
    var
        DataExch: Record "Data Exch.";
        DataExchField: Record "Data Exch. Field";
        EntryLink: Record "DataExch Entry Link ori";
        Request: JsonObject;
        DefCode: Code[20];
        FieldsBefore: Integer;
        LinksBefore: Integer;
    begin
        // [SCENARIO] Architect AC2 disposition: unexpected reader errors keep the Foundation shape and rollback.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(1);
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('contentBase64', Fixture.Encode('code,name,amount'));
        FieldsBefore := DataExchField.Count();
        LinksBefore := EntryLink.Count();
        Commit(); // Keep the fixture outside the failing import transaction.
        // The native AL boundary raises; the external API supplies BusinessCentralError.
        // Keep the actual reader error and prove rollback rather than swallowing it in a TryFunction.
        asserterror DispatchLocale("Message Type ori"::"DataExchange.Import.Run", Request, LanguageId);
        LibraryAssert.ExpectedError('The imported file contains unexpected formatting.');
        DataExch.SetRange("Data Exch. Def Code", DefCode);
        LibraryAssert.AreEqual(0, DataExch.Count(), 'The failed reader leaves no entry.');
        LibraryAssert.AreEqual(FieldsBefore, DataExchField.Count(), 'Parsed fields are rolled back.');
        LibraryAssert.AreEqual(LinksBefore, EntryLink.Count(), 'Entry link is rolled back.');
        DeleteDefinition(DefCode);
    end;

    [Test]
    procedure Utf16Csv_IsNotMistakenForBinary()
    var
        MessageArgument: Record "Message Argument ori";
        DataExchDef: Record "Data Exch. Def";
        ImportMgt: Codeunit "DataExch Import Mgt ori";
        TempBlob: Codeunit "Temp Blob";
        Content: OutStream;
        DefCode: Code[20];
    begin
        // [SCENARIO] UTF-16 text contains zero bytes but is a valid text file for its definition.
        DefCode := Fixture.CreateImportDefinition(0);
        DataExchDef.Get(DefCode);
        DataExchDef."File Encoding" := DataExchDef."File Encoding"::"UTF-16";
        DataExchDef.Modify();
        TempBlob.CreateOutStream(Content, TextEncoding::UTF16);
        Content.WriteText(Fixture.TwoLineCsv(false));
        LibraryAssert.IsTrue(ImportMgt.CheckFileFormat(MessageArgument, DefCode, TempBlob, 'contentBase64', ''), 'UTF-16 CSV must pass preflight.');
        LibraryAssert.IsFalse(MessageArgument.HasCollectedErrors(), 'No spurious format refusal.');
    end;

    local procedure CheckImportRefusal(LanguageId: Integer; Stored: Boolean; BinaryCsv: Boolean)
    var
        DataExch: Record "Data Exch.";
        DataExchField: Record "Data Exch. Field";
        EntryLink: Record "DataExch Entry Link ori";
        MockState: Codeunit "Storage Mock State";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
        Content: Text;
        ParameterName: Text;
        FieldsBefore: Integer;
        LinksBefore: Integer;
    begin
        // [SCENARIO] The real EN/IS queue rejects wrong-format content before any imported rows exist.
        Fixture.InitializeStorage();
        DefCode := CreateDefinition(BinaryCsv);
        Content := InvalidContent(BinaryCsv);
        Request.Add('dataExchDefCode', DefCode);
        ParameterName := 'contentBase64';
        if Stored then begin
            MockState.PutFile('in/bad.dat', Fixture.Encode(Content));
            Request.Add('storageCode', Fixture.StorageCode());
            Request.Add('path', 'in/bad.dat');
            ParameterName := 'path';
        end else
            Request.Add('contentBase64', Fixture.Encode(Content));
        FieldsBefore := DataExchField.Count();
        LinksBefore := EntryLink.Count();
        Response := DispatchLocale("Message Type ori"::"DataExchange.Import.Run", Request, LanguageId);
        AssertFormat(Response, ParameterName, ExpectedType(BinaryCsv), LanguageId, Content);
        DataExch.SetRange("Data Exch. Def Code", DefCode);
        LibraryAssert.AreEqual(0, DataExch.Count(), 'No imported header.');
        LibraryAssert.AreEqual(FieldsBefore, DataExchField.Count(), 'No parsed fields.');
        LibraryAssert.AreEqual(LinksBefore, EntryLink.Count(), 'No entry link.');
        if Stored then
            LibraryAssert.IsTrue(MockState.HasFile('in/bad.dat'), 'The source file stays in storage.');
        DeleteDefinition(DefCode);
    end;

    local procedure CheckDefinitionRefusal(LanguageId: Integer; Stored: Boolean)
    var
        DataExchDef: Record "Data Exch. Def";
        MockState: Codeunit "Storage Mock State";
        Request: JsonObject;
        Response: JsonObject;
        ParameterName: Text;
        BeforeCount: Integer;
    begin
        // [SCENARIO] Definition.Import identifies the actual source and never echoes its content.
        Fixture.InitializeStorage();
        BeforeCount := DataExchDef.Count();
        ParameterName := 'contentBase64';
        if Stored then begin
            MockState.PutFile('defs/bad.xml', Fixture.Encode(InvalidContent(false)));
            Request.Add('storageCode', Fixture.StorageCode());
            Request.Add('path', 'defs/bad.xml');
            ParameterName := 'path';
        end else
            Request.Add('contentBase64', Fixture.Encode(InvalidContent(false)));
        Response := DispatchLocale("Message Type ori"::"DataExchange.Definition.Import", Request, LanguageId);
        AssertFormat(Response, ParameterName, 'XML', LanguageId, InvalidContent(false));
        LibraryAssert.AreEqual(BeforeCount, DataExchDef.Count(), 'No definition is installed.');
    end;

    local procedure CheckUploadRefusal(LanguageId: Integer; BinaryCsv: Boolean; InstallDefinition: Boolean)
    var
        Session: Record "Storage Upload Session ori";
        Chunk: Record "Storage Upload Chunk ori";
        DataExch: Record "Data Exch.";
        Request: JsonObject;
        Response: JsonObject;
        UploadId: Text;
        UploadGuid: Guid;
        DefCode: Code[20];
        MessageType: Enum "Message Type ori";
    begin
        // [SCENARIO] A refusal preserves the complete upload for correction/retry, including process true.
        Fixture.InitializeStorage();
        DefCode := CreateDefinition(BinaryCsv);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('fileName', 'bad.dat');
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Upload.Begin", Request);
        UploadId := Fixture.ReadText(Fixture.Data(Response), 'uploadId');
        Evaluate(UploadGuid, UploadId);
        Clear(Request);
        Request.Add('uploadId', UploadId);
        Request.Add('sequence', 1);
        Request.Add('contentBase64', Fixture.Encode(InvalidContent(BinaryCsv)));
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Upload.Append", Request);
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Chunk created.');
        Clear(Request);
        Request.Add('uploadId', UploadId);
        MessageType := "Message Type ori"::"DataExchange.Definition.Import";
        if not InstallDefinition then begin
            MessageType := "Message Type ori"::"Storage.Upload.CommitToDataExchange";
            Request.Add('dataExchDefCode', DefCode);
            Request.Add('process', true);
        end;
        Response := DispatchLocale(MessageType, Request, LanguageId);
        AssertFormat(Response, 'uploadId', ExpectedType(BinaryCsv), LanguageId, InvalidContent(BinaryCsv));
        Session.Get(UploadGuid);
        LibraryAssert.AreEqual(Session.Status::Open, Session.Status, 'Session remains open.');
        LibraryAssert.AreEqual(1, Session."Chunk Count", 'Chunk remains.');
        Chunk.SetRange("Upload Id", UploadGuid);
        LibraryAssert.AreEqual(1, Chunk.Count(), 'Actual chunk row remains.');
        DataExch.SetRange("Data Exch. Def Code", DefCode);
        LibraryAssert.AreEqual(0, DataExch.Count(), 'No imported entry.');
        Session.Delete(true);
        DeleteDefinition(DefCode);
    end;

    local procedure CheckReadFailure(LanguageId: Integer; MessageType: Enum "Message Type ori")
    var
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] A missing storage file is an operational read failure, not a format refusal.
        Fixture.InitializeStorage();
        DefCode := CreateDefinition(false);
        if MessageType = "Message Type ori"::"DataExchange.Import.Run" then
            Request.Add('dataExchDefCode', DefCode);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'in/not-created.xml');
        Response := DispatchLocale(MessageType, Request, LanguageId);
        Fixture.AssertRefusal(Response, 'BusinessCentralError', 'path');
        LibraryAssert.AreEqual('in/not-created.xml', Fixture.ReadText(Response, 'received'), 'Name the source path.');
        DeleteDefinition(DefCode);
    end;

    local procedure CreateDefinition(BinaryCsv: Boolean) DefCode: Code[20]
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        DefCode := Fixture.CreateImportDefinition(0);
        if BinaryCsv then
            exit;
        DataExchDef.Get(DefCode);
        DataExchDef."File Type" := DataExchDef."File Type"::Xml;
        DataExchDef."Reading/Writing XMLport" := 0;
        DataExchDef."Reading/Writing Codeunit" := Codeunit::"Import XML File to Data Exch.";
        DataExchDef.Modify();
    end;

    local procedure DeleteDefinition(DefCode: Code[20])
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        DataExchDef.Get(DefCode);
        DataExchDef.Delete(true);
    end;

    local procedure InvalidContent(BinaryCsv: Boolean): Text
    var
        Control: Char;
    begin
        if not BinaryCsv then
            exit('ZZTA2010 not xml - private payload');
        Control := 1;
        exit('ZZT binary payload' + Format(Control));
    end;

    local procedure ExpectedType(BinaryCsv: Boolean): Text
    begin
        if BinaryCsv then
            exit('CSV');
        exit('XML');
    end;

    local procedure AssertFormat(Response: JsonObject; ParameterName: Text; Expected: Text; LanguageId: Integer; Content: Text)
    var
        Serialized: Text;
    begin
        Fixture.AssertRefusal(Response, 'InvalidParameterFormat', ParameterName);
        LibraryAssert.AreEqual(Expected, Fixture.ReadText(Response, 'expected'), 'Definition file type.');
        LibraryAssert.AreNotEqual('', Fixture.ReadText(Response, 'received'), 'Received contains file metadata.');
        if LanguageId = 1039 then
            LibraryAssert.IsTrue(Fixture.ReadText(Response, 'error').StartsWith('Ekki er hægt'), 'Icelandic error is translated.')
        else
            LibraryAssert.IsTrue(Fixture.ReadText(Response, 'error').StartsWith('The file cannot'), 'English error.');
        Response.WriteTo(Serialized);
        LibraryAssert.IsFalse(Serialized.Contains(Content), 'No file content in the refusal.');
        LibraryAssert.IsFalse(Serialized.Contains(Fixture.Encode(Content)), 'No encoded file content in the refusal.');
        LibraryAssert.IsFalse(Serialized.Contains('System.Xml'), 'No raw .NET parser text.');
    end;

    local procedure DispatchLocale(MessageType: Enum "Message Type ori"; Request: JsonObject; LanguageId: Integer) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        TaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseType: Text[100];
        Payload: Text;
    begin
        Request.WriteTo(Payload);
        RequestContent.AddText(Payload);
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, TaskId, LanguageId, MessageId, ResponseContent, ResponseType, ResponseTime);
        ResponseContent.GetSubText(Payload, 1);
        LibraryAssert.IsTrue(Response.ReadFrom(Payload), 'Real queue response must be JSON.');
    end;
}
