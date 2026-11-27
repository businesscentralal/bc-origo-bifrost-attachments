namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Bank.BankAccount;
using Microsoft.Bank.Setup;
using Microsoft.Finance.GeneralLedger.Journal;
using Origo.Bifrost;
using System.IO;
using System.TestLibraries.Utilities;

/// <summary>
/// #251: DataExchange.PaymentExport.Run refuses a batch with an already exported line unless the caller
/// sends reExport true, and then creates a new file. The bank format is the test double
/// DataExch Fake PayExport ori and the storage is the mock connector; no bank or storage service is called.
/// </summary>
codeunit 96248 "DataExch PayReExport251 ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "DataExch Fixture ori";
        LibraryAssert: Codeunit "Library Assert";
        TemplateTok: Label 'ZZDXPAY', Locked = true;
        BatchTok: Label 'RE251', Locked = true;
        BankTok: Label 'ZZPAY251', Locked = true;

    [Test]
    procedure AC01_AlreadyExported_Refused_1033()
    begin
        CheckAlreadyExportedRefused(1033);
    end;

    [Test]
    procedure AC01_AlreadyExported_Refused_1039()
    begin
        CheckAlreadyExportedRefused(1039);
    end;

    [Test]
    procedure AC01_ReExportFalse_Refused()
    var
        MockState: Codeunit "Storage Mock State";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] AC01: reExport false is the same as omitting it.
        Initialize();
        MarkExported(20000);
        Request := NewRequest('out/re251-false.txt');
        Request.Add('reExport', false);
        Response := Dispatch(Request, 1033);
        Fixture.AssertRefusal(Response, 'PreconditionFailed', 'reExport');
        LibraryAssert.IsFalse(MockState.HasFile('out/re251-false.txt'), 'AC01 no file is created.');
    end;

    [Test]
    procedure AC02_ReExportTrue_CreatesNewFile_1033()
    begin
        CheckReExportCreatesNewFile(1033);
    end;

    [Test]
    procedure AC02_ReExportTrue_CreatesNewFile_1039()
    begin
        CheckReExportCreatesNewFile(1039);
    end;

    [Test]
    procedure AC03_NotExported_ExportsWithoutParameter()
    var
        Request: JsonObject;
    begin
        // [SCENARIO] AC03: a batch with no exported line exports as before without the parameter.
        Initialize();
        Request := NewRequest('out/re251-plain.txt');
        AssertExported(Dispatch(Request, 1033), 'out/re251-plain.txt', 'AC03 without reExport');
    end;

    [Test]
    procedure AC03_NotExported_ExportsWithReExport()
    var
        Request: JsonObject;
    begin
        // [SCENARIO] AC03: a batch with no exported line exports as before with reExport true.
        Initialize();
        Request := NewRequest('out/re251-plain-true.txt');
        Request.Add('reExport', true);
        AssertExported(Dispatch(Request, 1033), 'out/re251-plain-true.txt', 'AC03 with reExport');
    end;

    [Test]
    procedure ReExportNotBoolean_InvalidParameterFormat()
    var
        Request: JsonObject;
    begin
        // [SCENARIO] Invalid input: reExport must be a JSON boolean.
        Initialize();
        MarkExported(10000);
        Request := NewRequest('out/re251-bad.txt');
        Request.Add('reExport', 'yes');
        Fixture.AssertRefusal(Dispatch(Request, 1033), 'InvalidParameterFormat', 'reExport');
        LibraryAssert.AreEqual(0, DataExchCount(), 'Nothing was exported.');
    end;

    local procedure CheckAlreadyExportedRefused(LanguageId: Integer)
    var
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
        Problem: JsonObject;
    begin
        // [SCENARIO] AC01: one exported line and no reExport: refused, the line is named, no file is created.
        Initialize();
        MarkExported(20000);
        Response := Dispatch(NewRequest('out/re251-refused.txt'), LanguageId);
        Fixture.AssertRefusal(Response, 'PreconditionFailed', 'reExport');
        Problem := FirstProblem(Response);
        LibraryAssert.IsTrue(Fixture.ReadText(Problem, 'error').Contains('20000'), 'AC01 names the exported line. ' + Fixture.ReadText(Problem, 'error'));
        LibraryAssert.IsFalse(Fixture.ReadText(Problem, 'error').Contains('10000'), 'AC01 does not name a line that is not exported.');
        LibraryAssert.IsTrue(Fixture.ReadText(Problem, 'nextStep').Contains('reExport=true'), 'AC01 nextStep names reExport=true. ' + Fixture.ReadText(Problem, 'nextStep'));
        LibraryAssert.AreEqual('false', Fixture.ReadText(Problem, 'received'), 'AC01 received.');
        if LanguageId = 1039 then
            LibraryAssert.IsTrue(Fixture.ReadText(Problem, 'nextStep').StartsWith('Stilltu'), 'AC01 nextStep in Icelandic. ' + Fixture.ReadText(Problem, 'nextStep'));
        LibraryAssert.IsFalse(MockState.HasFile('out/re251-refused.txt'), 'AC01 no file is created.');
        LibraryAssert.AreEqual(0, DataExchCount(), 'AC01 no export entry is created.');
        LibraryAssert.AreEqual(1, ExportedLineCount(), 'AC01 the line marks are unchanged.');
    end;

    local procedure CheckReExportCreatesNewFile(LanguageId: Integer)
    var
        MockState: Codeunit "Storage Mock State";
        Request: JsonObject;
        Response: JsonObject;
        FirstEntryNo: Integer;
        SecondEntryNo: Integer;
    begin
        // [SCENARIO] AC02: export, then export the same batch again with reExport true: a new file and entry.
        Initialize();
        Response := Dispatch(NewRequest('out/re251-first.txt'), LanguageId);
        FirstEntryNo := AssertExported(Response, 'out/re251-first.txt', 'AC02 first export');
        Response := Dispatch(NewRequest('out/re251-again.txt'), LanguageId);
        Fixture.AssertRefusal(Response, 'PreconditionFailed', 'reExport');
        Request := NewRequest('out/re251-again.txt');
        Request.Add('reExport', true);
        Response := Dispatch(Request, LanguageId);
        SecondEntryNo := AssertExported(Response, 'out/re251-again.txt', 'AC02 re-export');
        LibraryAssert.AreNotEqual(FirstEntryNo, SecondEntryNo, 'AC02 a new export entry.');
        LibraryAssert.AreNotEqual(MockState.GetFileContent('out/re251-first.txt'), MockState.GetFileContent('out/re251-again.txt'), 'AC02 a new file.');
        LibraryAssert.AreEqual(2, DataExchCount(), 'AC02 two export entries.');
    end;

    local procedure AssertExported(Response: JsonObject; Path: Text; Context: Text) EntryNo: Integer
    var
        MockState: Codeunit "Storage Mock State";
        Data: JsonObject;
    begin
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), Context + ' status. ' + Fixture.ReadText(Response, 'error'));
        Data := Fixture.Data(Response);
        LibraryAssert.AreEqual(Path, Fixture.ReadText(Data, 'path'), Context + ' path.');
        LibraryAssert.AreEqual(2, Fixture.ReadInt(Data, 'lineCount'), Context + ' lineCount.');
        LibraryAssert.AreEqual(2, Fixture.ReadInt(Data, 'exportedLineCount'), Context + ' exportedLineCount.');
        LibraryAssert.AreNotEqual('', Fixture.ReadText(Data, 'fileName'), Context + ' fileName.');
        LibraryAssert.IsTrue(MockState.HasFile(Path), Context + ' file in storage.');
        EntryNo := Fixture.ReadInt(Data, 'entryNo');
        LibraryAssert.AreNotEqual(0, EntryNo, Context + ' entryNo.');
    end;

    local procedure Initialize()
    var
        GenJournalTemplate: Record "Gen. Journal Template";
        GenJournalBatch: Record "Gen. Journal Batch";
        GenJournalLine: Record "Gen. Journal Line";
        BankExportImportSetup: Record "Bank Export/Import Setup";
        BankAccount: Record "Bank Account";
        DataExch: Record "Data Exch.";
    begin
        Fixture.InitializeStorage();
        DataExch.SetRange("Data Exch. Def Code", BankTok);
        DataExch.DeleteAll(true);
        if not GenJournalTemplate.Get(TemplateTok) then begin
            GenJournalTemplate.Init();
            GenJournalTemplate.Name := TemplateTok;
            GenJournalTemplate.Type := GenJournalTemplate.Type::Payments;
            GenJournalTemplate.Insert();
        end;
        if not GenJournalBatch.Get(TemplateTok, BatchTok) then begin
            GenJournalBatch.Init();
            GenJournalBatch."Journal Template Name" := TemplateTok;
            GenJournalBatch.Name := BatchTok;
            GenJournalBatch.Insert();
        end;
        if not BankExportImportSetup.Get(BankTok) then begin
            BankExportImportSetup.Init();
            BankExportImportSetup.Code := BankTok;
            BankExportImportSetup.Direction := BankExportImportSetup.Direction::Export;
            BankExportImportSetup."Processing Codeunit ID" := Codeunit::"DataExch Fake PayExport ori";
            BankExportImportSetup.Insert();
        end;
        if not BankAccount.Get(BankTok) then begin
            BankAccount.Init();
            BankAccount."No." := BankTok;
            BankAccount.Name := BankTok;
            BankAccount."Payment Export Format" := BankTok;
            BankAccount.Insert();
        end;
        GenJournalLine.SetRange("Journal Template Name", TemplateTok);
        GenJournalLine.SetRange("Journal Batch Name", BatchTok);
        GenJournalLine.DeleteAll();
        InsertLine(10000);
        InsertLine(20000);
    end;

    local procedure InsertLine(LineNo: Integer)
    var
        GenJournalLine: Record "Gen. Journal Line";
    begin
        GenJournalLine.Init();
        GenJournalLine."Journal Template Name" := TemplateTok;
        GenJournalLine."Journal Batch Name" := BatchTok;
        GenJournalLine."Line No." := LineNo;
        GenJournalLine."Document Type" := GenJournalLine."Document Type"::Payment;
        GenJournalLine."Document No." := BatchTok;
        GenJournalLine."Posting Date" := WorkDate();
        GenJournalLine."Account Type" := GenJournalLine."Account Type"::"G/L Account";
        GenJournalLine."Bal. Account Type" := GenJournalLine."Bal. Account Type"::"Bank Account";
        GenJournalLine."Bal. Account No." := BankTok;
        GenJournalLine.Amount := 100;
        GenJournalLine.Insert();
    end;

    local procedure MarkExported(LineNo: Integer)
    var
        GenJournalLine: Record "Gen. Journal Line";
    begin
        GenJournalLine.Get(TemplateTok, BatchTok, LineNo);
        GenJournalLine."Exported to Payment File" := true;
        GenJournalLine.Modify();
    end;

    local procedure ExportedLineCount(): Integer
    var
        GenJournalLine: Record "Gen. Journal Line";
    begin
        GenJournalLine.SetRange("Journal Template Name", TemplateTok);
        GenJournalLine.SetRange("Journal Batch Name", BatchTok);
        GenJournalLine.SetRange("Exported to Payment File", true);
        exit(GenJournalLine.Count());
    end;

    local procedure DataExchCount(): Integer
    var
        DataExch: Record "Data Exch.";
    begin
        DataExch.SetRange("Data Exch. Def Code", BankTok);
        exit(DataExch.Count());
    end;

    local procedure NewRequest(Path: Text) Request: JsonObject
    begin
        Request.Add('journalTemplate', TemplateTok);
        Request.Add('journalBatch', BatchTok);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', Path);
    end;

    local procedure FirstProblem(Response: JsonObject): JsonObject
    var
        Token: JsonToken;
    begin
        if Response.Get('errors', Token) then
            if Token.IsArray() then
                if Token.AsArray().Get(0, Token) then
                    exit(Token.AsObject());
        exit(Response);
    end;

    local procedure Dispatch(Request: JsonObject; LanguageId: Integer) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        TestConfirmation: Codeunit "Storage Test Confirmation ori";
        ResponseText: Text;
    begin
        Response := TestConfirmation.Dispatch(Dispatcher, "Message Type ori"::"DataExchange.PaymentExport.Run", Request, LanguageId, false);
        Response.WriteTo(ResponseText);
        LibraryAssert.IsTrue(Response.ReadFrom(ResponseText), 'A dispatch must return JSON.');
    end;
}
