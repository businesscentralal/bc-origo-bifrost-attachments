namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.TestLibraries.Utilities;

/// <summary>
/// Phase 3 (#25): DataExchange.Export.Run runs a Generic Export definition over a table view or
/// record SystemIds and delivers the file to storage or inline; DataExchange.PaymentExport.Run
/// (3b) refuses batches it cannot export before anything is written.
/// </summary>
codeunit 96243 "DataExch Export Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "DataExch Fixture ori";
        LibraryAssert: Codeunit "Library Assert";
        OneCustomerViewTok: Label 'WHERE(No.=FILTER(%1))', Locked = true;
        ThreeCustomersViewTok: Label 'WHERE(No.=FILTER(%1|%2|%3))', Locked = true;

    [Test]
    procedure AC01_ExportThreeCustomers_ToStorage()
    var
        Customer: Record Customer;
        MockState: Codeunit "Storage Mock State";
        CustomerNos: List of [Code[20]];
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
        Content: Text;
        Lines: List of [Text];
    begin
        // [SCENARIO] AC01: a view on three customers writes a file with three data lines to storage.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateExportDefinition();
        CustomerNos := Fixture.CreateCustomers(3, 'DXE AC01');
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('tableId', Database::Customer);
        Request.Add('tableView', StrSubstNo(ThreeCustomersViewTok, CustomerNos.Get(1), CustomerNos.Get(2), CustomerNos.Get(3)));
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'out/ac01.csv');

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Export.Run", Request);

        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'AC01 status. ' + Fixture.ReadText(Response, 'error'));
        LibraryAssert.AreEqual(3, Fixture.ReadInt(Fixture.Data(Response), 'recordCount'), 'AC01 recordCount 3.');
        LibraryAssert.AreEqual('out/ac01.csv', Fixture.ReadText(Fixture.Data(Response), 'path'), 'AC01 path.');
        LibraryAssert.AreNotEqual(0, Fixture.ReadInt(Fixture.Data(Response), 'entryNo'), 'AC01 entry.');
        LibraryAssert.IsFalse(Fixture.Data(Response).Contains('contentBase64'), 'AC01 nothing inline.');
        LibraryAssert.IsTrue(MockState.HasFile('out/ac01.csv'), 'AC01 file in storage.');
        Content := Fixture.Decode(MockState.GetFileContent('out/ac01.csv'));
        Lines := Content.TrimEnd().Split(LineBreak());
        LibraryAssert.AreEqual(3, Lines.Count(), 'AC01 three data lines.');
        Customer.Get(CustomerNos.Get(1));
        LibraryAssert.IsTrue(Content.Contains(Customer."No."), 'AC01 file carries the customer number.');
        LibraryAssert.IsTrue(Content.Contains(Customer.Name), 'AC01 file carries the customer name.');
        LibraryAssert.AreEqual(StrLen(Content), Fixture.ReadInt(Fixture.Data(Response), 'contentLength'), 'AC01 contentLength.');
    end;

    [Test]
    procedure AC02_RecordIds_InlineAndStorage()
    var
        Customer: Record Customer;
        MockState: Codeunit "Storage Mock State";
        CustomerNos: List of [Code[20]];
        Request: JsonObject;
        Response: JsonObject;
        RecordIds: JsonArray;
        CustomerNo: Code[20];
        DefCode: Code[20];
        Inline: Text;
    begin
        // [SCENARIO] AC02: recordIds with inline true returns the file and also stores it when storageCode is given.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateExportDefinition();
        CustomerNos := Fixture.CreateCustomers(2, 'DXE AC02');
        foreach CustomerNo in CustomerNos do begin
            Customer.Get(CustomerNo);
            RecordIds.Add(Format(Customer.SystemId, 0, 4));
        end;
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('recordIds', RecordIds);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('folderPath', 'out');
        Request.Add('fileName', 'ac02.csv');
        Request.Add('inline', true);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Export.Run", Request);

        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'AC02 status. ' + Fixture.ReadText(Response, 'error'));
        LibraryAssert.AreEqual(2, Fixture.ReadInt(Fixture.Data(Response), 'recordCount'), 'AC02 recordCount 2.');
        LibraryAssert.AreEqual('out/ac02.csv', Fixture.ReadText(Fixture.Data(Response), 'path'), 'AC02 folderPath plus file name.');
        Inline := Fixture.ReadText(Fixture.Data(Response), 'contentBase64');
        LibraryAssert.AreNotEqual('', Inline, 'AC02 inline content.');
        LibraryAssert.AreEqual(Inline, MockState.GetFileContent('out/ac02.csv'), 'AC02 stored and inline bytes are the same.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure AC03_InlineOverOneMegabyte_RollsBack()
    var
        DataExchDef: Record "Data Exch. Def";
        CustomerNos: List of [Code[20]];
        Request: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] AC03: a result over 1 MB with inline true is refused and the export is rolled back.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateExportDefinition();
        DataExchDef.Get(DefCode);
        DataExchDef."Reading/Writing Codeunit" := Codeunit::"DataExch Test Big Writer ori";
        DataExchDef.Modify();
        CustomerNos := Fixture.CreateCustomers(1, 'DXE AC03');
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('tableId', Database::Customer);
        Request.Add('tableView', StrSubstNo(OneCustomerViewTok, CustomerNos.Get(1)));
        Request.Add('inline', true);
        // asserterror rolls back the open transaction; commit the fixture so only the export is undone.
        Commit();

        asserterror Fixture.Dispatch("Message Type ori"::"DataExchange.Export.Run", Request);

        LibraryAssert.IsTrue(GetLastErrorText().Contains('1 MB'), 'AC03 names the 1 MB limit: ' + GetLastErrorText());
        LibraryAssert.AreEqual(0, EntryCount(DefCode), 'AC03 leaves no entry.');
    end;

    [Test]
    procedure AC04_ImportDefinition_Refused()
    var
        Request: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] AC04: an import definition cannot export.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('tableId', Database::Customer);
        Request.Add('inline', true);

        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Export.Run", Request), 'InvalidParameter', 'dataExchDefCode');
        LibraryAssert.AreEqual(0, EntryCount(DefCode), 'AC04 writes nothing.');
    end;

    [Test]
    procedure AC04_PaymentDefinition_PointsToPaymentExport()
    var
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] AC04: a payment export definition points to DataExchange.PaymentExport.Run.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateBareDefinition("Data Exchange Definition Type"::"Payment Export");
        Request.Add('tableId', Database::Customer);
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('inline', true);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Export.Run", Request);

        Fixture.AssertRefusal(Response, 'InvalidParameter', 'dataExchDefCode');
        LibraryAssert.IsTrue(Fixture.ReadText(Response, 'nextStep').Contains('DataExchange.PaymentExport.Run'), 'Names the payment export type.');
    end;

    [Test]
    procedure TableNotMappingTable_Refused()
    var
        Request: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] A table other than the mapping table is refused.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateExportDefinition();
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('tableId', Database::"Data Exch. Def");
        Request.Add('inline', true);

        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Export.Run", Request), 'InvalidParameter', 'tableId');
        LibraryAssert.AreEqual(0, EntryCount(DefCode), 'Nothing is written.');
    end;

    [Test]
    procedure MissingSourceAndDelivery_CollectedTogether()
    var
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] Without a record selection and a delivery both problems are answered at once.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateExportDefinition();
        Request.Add('dataExchDefCode', DefCode);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Export.Run", Request);

        Fixture.AssertRefusal(Response, 'MissingParameter', 'tableId');
        Fixture.AssertRefusal(Response, 'MissingParameter', 'storageCode');
    end;

    [Test]
    procedure NoMatchingRecords_PreconditionFailed()
    var
        Request: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] A view that matches nothing is refused before any write.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateExportDefinition();
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('tableId', Database::Customer);
        Request.Add('tableView', 'WHERE(No.=FILTER(ZZNOSUCHCUSTOMER))');
        Request.Add('inline', true);

        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Export.Run", Request), 'PreconditionFailed', 'tableView');
        LibraryAssert.AreEqual(0, EntryCount(DefCode), 'Nothing is written.');
    end;

    [Test]
    procedure UnknownViewField_InvalidFilterField()
    var
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] The tableView is validated: an unknown field fails closed.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateExportDefinition();
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('tableId', Database::Customer);
        Request.Add('tableView', 'WHERE(NoSuchField=FILTER(X))');
        Request.Add('inline', true);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Export.Run", Request);

        LibraryAssert.AreEqual('Error', Fixture.ReadText(Response, 'status'), 'Unknown field refused.');
        LibraryAssert.AreEqual(0, EntryCount(DefCode), 'Nothing is written.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure StorageWriteFailure_RollsBackEntry()
    var
        MockState: Codeunit "Storage Mock State";
        CustomerNos: List of [Code[20]];
        Request: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] A failed storage write rolls the export back.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateExportDefinition();
        CustomerNos := Fixture.CreateCustomers(1, 'DXE FAIL');
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('tableId', Database::Customer);
        Request.Add('tableView', StrSubstNo(OneCustomerViewTok, CustomerNos.Get(1)));
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'out/fail.csv');
        MockState.FailNextWrite();
        Commit();

        asserterror Fixture.Dispatch("Message Type ori"::"DataExchange.Export.Run", Request);

        LibraryAssert.AreEqual(0, EntryCount(DefCode), 'No entry stays.');
        LibraryAssert.IsFalse(MockState.HasFile('out/fail.csv'), 'No file stays.');
    end;

    [Test]
    procedure PaymentExport_UnknownBatch_RecordNotFound()
    var
        Request: JsonObject;
    begin
        // [SCENARIO] AC05 refusal: an unknown journal batch is refused before anything runs.
        Fixture.InitializeStorage();
        Request.Add('journalTemplate', 'ZZNOTPL');
        Request.Add('journalBatch', 'ZZNOBATCH');
        Request.Add('inline', true);

        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.PaymentExport.Run", Request), 'RecordNotFound', 'journalBatch');
    end;

    [Test]
    procedure PaymentExport_LowercaseName_InvalidParameterFormat()
    var
        Request: JsonObject;
    begin
        // [SCENARIO] Journal names are taken exactly as stored; a lowercase name is refused, not upper-cased.
        Fixture.InitializeStorage();
        Request.Add('journalTemplate', 'payment');
        Request.Add('journalBatch', 'DEFAULT');
        Request.Add('inline', true);

        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.PaymentExport.Run", Request), 'InvalidParameterFormat', 'journalTemplate');
    end;

    [Test]
    procedure PaymentExport_EmptyBatch_PreconditionFailed()
    var
        GenJournalTemplate: Record "Gen. Journal Template";
        GenJournalBatch: Record "Gen. Journal Batch";
        Request: JsonObject;
    begin
        // [SCENARIO] A batch without lines has nothing to export.
        Fixture.InitializeStorage();
        GenJournalTemplate.Init();
        GenJournalTemplate.Name := 'ZZDXPAY';
        GenJournalTemplate.Type := GenJournalTemplate.Type::Payments;
        if GenJournalTemplate.Insert() then;
        GenJournalBatch.Init();
        GenJournalBatch."Journal Template Name" := 'ZZDXPAY';
        GenJournalBatch.Name := 'EMPTY';
        if GenJournalBatch.Insert() then;
        Request.Add('journalTemplate', 'ZZDXPAY');
        Request.Add('journalBatch', 'EMPTY');
        Request.Add('inline', true);

        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.PaymentExport.Run", Request), 'PreconditionFailed', 'journalBatch');
    end;

    [Test]
    procedure PaymentExport_NoDelivery_MissingParameter()
    var
        Request: JsonObject;
    begin
        // [SCENARIO] A payment export without storageCode or inline is refused.
        Request.Add('journalTemplate', 'ZZDXPAY');
        Request.Add('journalBatch', 'EMPTY');

        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.PaymentExport.Run", Request), 'MissingParameter', 'storageCode');
    end;

    local procedure EntryCount(DefCode: Code[20]): Integer
    var
        DataExch: Record "Data Exch.";
    begin
        DataExch.SetRange("Data Exch. Def Code", DefCode);
        exit(DataExch.Count());
    end;

    local procedure LineBreak(): Text
    var
        Lf: Text[1];
    begin
        Lf[1] := 10;
        exit(Lf);
    end;
}
