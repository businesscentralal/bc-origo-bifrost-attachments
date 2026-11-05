namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.ExternalFileStorage;
using System.IO;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Regressions for issue 210: parameter-first previews, mapping identity, bounded diagnostics and product Mock.</summary>
codeunit 96279 "Storage UAT210 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit "Library Assert";
        Fixture: Codeunit "DataExch Fixture ori";

    /// <summary>Absent payment targets must not become a confirmation preview in either language.</summary>
    [Test]
    procedure MissingPaymentTargetBeforeConfirmation()
    begin
        AssertMissingTarget("Message Type ori"::"DataExchange.PaymentExport.Run", 1033);
        AssertMissingTarget("Message Type ori"::"DataExchange.PaymentExport.Run", 1039);
    end;

    /// <summary>Absent definition code must not become a confirmation preview in either language.</summary>
    [Test]
    procedure MissingDefinitionBeforeConfirmation()
    begin
        AssertMissingTarget("Message Type ori"::"DataExchange.Definition.Export", 1033);
        AssertMissingTarget("Message Type ori"::"DataExchange.Definition.Export", 1039);
    end;

    /// <summary>A declared zero table mapping is a typed, named refusal without opening table zero.</summary>
    [Test]
    procedure ZeroTableMappingNamesDefinitionAndLine()
    begin
        AssertMappingRefusal(1033);
        AssertMappingRefusal(1039);
    end;

    /// <summary>Unmapped root definitions and stale entry line context cannot open table zero.</summary>
    [Test]
    procedure MappedLinesIgnoreUnmappedRootAndStaleContext()
    begin
        AssertMappedLines(1033, false);
        AssertMappedLines(1039, false);
        AssertMappedLines(1033, true);
        AssertMappedLines(1039, true);
    end;

    local procedure AssertMappedLines(LanguageId: Integer; ProcessDuringImport: Boolean)
    var
        Entry: Record "Data Exch.";
        LineDef: Record "Data Exch. Line Def";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
        EntryNo: Integer;
        PriorLanguage: Integer;
    begin
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        LineDef.Init();
        LineDef."Data Exch. Def Code" := DefCode;
        LineDef.Code := 'AUNMAPPED';
        LineDef.Name := 'Unmapped root';
        LineDef.Insert();
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('contentBase64', Fixture.Encode(Fixture.TwoLineCsv(false)));
        Request.Add('fileName', 'X210-mapped.csv');
        Request.Add('process', ProcessDuringImport);
        PriorLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Import.Run", Request);
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Import with unmapped root. ' + Format(Response));
        EntryNo := Fixture.ReadInt(Fixture.Data(Response), 'entryNo');
        if not ProcessDuringImport then begin
            Entry.Get(EntryNo);
            Entry."Data Exch. Line Def Code" := 'AUNMAPPED';
            Entry.Modify();
            Clear(Request);
            Request.Add('entryNo', EntryNo);
            Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Entry.Process", Request);
            LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Process ignores stale line. ' + Format(Response));
        end;
        LibraryAssert.AreEqual(2, Fixture.TargetCount(EntryNo), 'The actual mapped line writes two rows.');
        GlobalLanguage(PriorLanguage);
    end;

    /// <summary>Malformed base64 retains only a bounded received value in both languages.</summary>
    [Test]
    procedure InvalidBase64ReceivedIsBounded()
    begin
        AssertBase64Refusal(1033);
        AssertBase64Refusal(1039);
    end;

    /// <summary>The production Mock performs every connector operation and isolates connection identities.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure ProductMockRoundtripAndIsolation()
    var
        FirstSetup: Record "Storage Setup ori";
        SecondSetup: Record "Storage Setup ori";
        TempEntries: Record "File Account Content" temporary;
        Content: Codeunit "Temp Blob";
        Result: Codeunit "Temp Blob";
        Connector: Interface "Storage Connector ori";
        Source: InStream;
        Destination: OutStream;
        TextValue: Text;
    begin
        CreateMockSetup(FirstSetup);
        CreateMockSetup(SecondSetup);
        Connector := FirstSetup."Storage Type";
        Connector.TestConnection(FirstSetup);
        Connector.CreateDirectory(FirstSetup, 'Xdir');
        LibraryAssert.IsTrue(Connector.DirectoryExists(FirstSetup, 'Xdir'), 'Explicit directory exists.');
        Connector.ListEntries(FirstSetup, '', Enum::"Ext. File Storage File Type"::Directory, TempEntries);
        LibraryAssert.AreEqual(1, TempEntries.Count(), 'List directory.');
        Content.CreateOutStream(Destination, TextEncoding::UTF8);
        Destination.WriteText('Mock bytes');
        Connector.CreateFile(FirstSetup, 'Xdir/one.txt', Content);
        LibraryAssert.IsTrue(Connector.FileExists(FirstSetup, 'Xdir/one.txt'), 'Created file exists.');
        LibraryAssert.IsFalse(Connector.FileExists(SecondSetup, 'Xdir/one.txt'), 'No cross-connection file.');
        Connector.GetFile(FirstSetup, 'Xdir/one.txt', Result);
        Result.CreateInStream(Source, TextEncoding::UTF8);
        Source.ReadText(TextValue);
        LibraryAssert.AreEqual('Mock bytes', TextValue, 'File bytes roundtrip.');
        Connector.CopyFile(FirstSetup, 'Xdir/one.txt', 'Xdir/two.txt');
        Connector.MoveFile(FirstSetup, 'Xdir/two.txt', 'Xdir/three.txt');
        LibraryAssert.IsFalse(Connector.FileExists(FirstSetup, 'Xdir/two.txt'), 'Move removes old name.');
        Connector.ListEntries(FirstSetup, 'Xdir', Enum::"Ext. File Storage File Type"::File, TempEntries);
        LibraryAssert.AreEqual(2, TempEntries.Count(), 'Copy and move leave two files.');
        Commit(); // Preserve the fixture outside the deliberate failed deletion.
        asserterror Connector.DeleteDirectory(FirstSetup, 'Xdir');
        ClearLastError();
        Connector.DeleteFile(FirstSetup, 'Xdir/one.txt');
        Connector.DeleteFile(FirstSetup, 'Xdir/three.txt');
        Connector.DeleteDirectory(FirstSetup, 'Xdir');
        LibraryAssert.IsFalse(Connector.DirectoryExists(FirstSetup, 'Xdir'), 'Directory removed.');
        FirstSetup.Delete(true);
        SecondSetup.Delete(true);
    end;

    /// <summary>Deleting an owned connection removes its persisted Mock content.</summary>
    [Test]
    procedure ProductMockSetupCleanup()
    var
        Setup: Record "Storage Setup ori";
        Entry: Record "Storage Mock Entry ori";
        Content: Codeunit "Temp Blob";
        Connector: Interface "Storage Connector ori";
        OwnedCode: Code[20];
    begin
        CreateMockSetup(Setup);
        OwnedCode := Setup.Code;
        Connector := Setup."Storage Type";
        Connector.CreateFile(Setup, 'Xempty.txt', Content);
        Setup.Delete(true);
        Entry.SetRange("Storage Code", OwnedCode);
        LibraryAssert.IsTrue(Entry.IsEmpty(), 'Connection cleanup removes all owned Mock content.');
    end;

    /// <summary>Unreadable uploads refuse before writes and retain their open session and chunks.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure UnreadableUploadRetainsContextAndState()
    begin
        AssertReaderContext(1033);
        AssertReaderContext(1039);
    end;

    local procedure AssertReaderContext(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Session: Record "Storage Upload Session ori";
        Chunk: Record "Storage Upload Chunk ori";
        Entry: Record "Data Exch.";
        UploadMgt: Codeunit "Storage Upload Mgt ori";
        Request: JsonObject;
        Response: JsonObject;
        Result: JsonObject;
        DefCode: Code[20];
        UploadId: Text;
        UploadGuid: Guid;
        PriorLanguage: Integer;
    begin
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(1);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('fileName', 'X210-unreadable.csv');
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Upload.Begin", Request);
        UploadId := Fixture.ReadText(Fixture.Data(Response), 'uploadId');
        Evaluate(UploadGuid, UploadId);
        Clear(Request);
        Request.Add('uploadId', UploadId);
        Request.Add('sequence', 1);
        Request.Add('contentBase64', Fixture.Encode('code,name,amount'));
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Upload.Append", Request);
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Seed the unreadable header-only CSV.');
        Clear(Request);
        Request.Add('uploadId', UploadId);
        Request.Add('dataExchDefCode', DefCode);
        TempArgument.Init();
        TempArgument.Type := "Message Type ori"::"Storage.Upload.CommitToDataExchange";
        TempArgument.SetRequestJson(Request);
        PriorLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Commit();
        LibraryAssert.IsFalse(UploadMgt.CommitToDataExchange(TempArgument, Result), 'Unreadable CSV refuses before writes.');
        Response := TempArgument.GetResponseJson();
        Fixture.AssertRefusal(Response, 'InvalidParameterFormat', 'uploadId');
        LibraryAssert.AreNotEqual('', Fixture.ReadText(Response, 'nextStep'), 'Native reader refusal carries retry guidance.');
        Session.Get(UploadGuid);
        LibraryAssert.AreEqual(Session.Status::Open, Session.Status, 'Upload stays open after reader failure.');
        Chunk.SetRange("Upload Id", UploadGuid);
        LibraryAssert.AreEqual(1, Chunk.Count(), 'Uploaded chunk retained.');
        Entry.SetRange("Data Exch. Def Code", DefCode);
        LibraryAssert.IsTrue(Entry.IsEmpty(), 'No partially imported entry.');
        TempArgument.ClearErrorContext();
        Session.Delete(true);
        GlobalLanguage(PriorLanguage);
    end;

    local procedure AssertMissingTarget(MessageType: Enum "Message Type ori"; LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Counter: Interface "Msg Confirm ori";
        Count: Integer;
        Summary: Text;
        PriorLanguage: Integer;
        Request: JsonObject;
        Response: JsonObject;
    begin
        PriorLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        TempArgument.Init();
        TempArgument.Type := MessageType;
        TempArgument.SetRequestJson(Request);
        Counter := MessageType;
        LibraryAssert.IsFalse(Counter.GetConfirmCount(TempArgument, Count, Summary), 'Missing target must refuse before confirmation.');
        Response := TempArgument.GetResponseJson();
        // Payment has two independent missing fields, definition has one.
        if MessageType = "Message Type ori"::"DataExchange.PaymentExport.Run" then
            Fixture.AssertRefusal(Response, 'MissingParameter', 'journalTemplate')
        else
            Fixture.AssertRefusal(Response, 'MissingParameter', 'code');
        LibraryAssert.AreNotEqual('ConfirmationRequired', Fixture.ReadText(Response, 'code'), 'No preview of an invalid request.');
        GlobalLanguage(PriorLanguage);
    end;

    local procedure AssertMappingRefusal(LanguageId: Integer)
    var
        Entry: Record "Data Exch.";
        Mapping: Record "Data Exch. Mapping";
        ImportMgt: Codeunit "DataExch Import Mgt ori";
        ErrorCode: Enum "Bifrost Error Code ori";
        DefCode: Code[20];
        ErrorText: Text;
        Expected: Text;
        NextStep: Text;
        PriorLanguage: Integer;
    begin
        PriorLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        DefCode := Fixture.CreateImportDefinition(0);
        Mapping.SetRange("Data Exch. Def Code", DefCode);
        Mapping.FindFirst();
        Mapping.Rename(DefCode, Mapping."Data Exch. Line Def Code", 0);
        Entry."Data Exch. Def Code" := DefCode;
        LibraryAssert.IsTrue(ImportMgt.FindProcessBlocker(Entry, '', ErrorCode, ErrorText, Expected, NextStep), 'Zero table is blocked.');
        LibraryAssert.AreEqual(Enum::"Bifrost Error Code ori"::PreconditionFailed, ErrorCode, 'Typed mapping refusal.');
        LibraryAssert.IsTrue(ErrorText.Contains(DefCode), 'Refusal identifies the definition.');
        LibraryAssert.IsTrue(ErrorText.Contains(Mapping."Data Exch. Line Def Code"), 'Refusal identifies the line.');
        LibraryAssert.AreNotEqual('', NextStep, 'Mapping recovery guidance.');
        GlobalLanguage(PriorLanguage);
    end;

    local procedure AssertBase64Refusal(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Reader: Codeunit "Storage Request Reader ori";
        Content: Codeunit "Temp Blob";
        Request: JsonObject;
        Response: JsonObject;
        InvalidContent: Text;
        PriorLanguage: Integer;
    begin
        PriorLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        InvalidContent := PadStr('!', 300, '!');
        Request.Add('contentBase64', InvalidContent);
        LibraryAssert.IsFalse(Reader.ReadBase64Content(TempArgument, Request, 'contentBase64', true, Content), 'Invalid base64.');
        Reader.RespondIfErrors(TempArgument);
        Response := TempArgument.GetResponseJson();
        Fixture.AssertRefusal(Response, 'InvalidParameterFormat', 'contentBase64');
        LibraryAssert.AreEqual(CopyStr(InvalidContent, 1, 250), Fixture.ReadText(Response, 'received'), 'received truncates at 250 characters.');
        GlobalLanguage(PriorLanguage);
    end;

    local procedure CreateMockSetup(var Setup: Record "Storage Setup ori")
    begin
        Setup.Init();
        Setup.Code := CopyStr('X210' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(Setup.Code));
        Setup."Storage Type" := Setup."Storage Type"::Mock;
        Setup.Enabled := true;
        Setup.Insert(true);
    end;
}
