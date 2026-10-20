namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.TestLibraries.Utilities;

/// <summary>
/// Phase 4 (#26): DataExchange.Definition.Import installs the standard definition XML from storage,
/// inline content or an upload; DataExchange.Definition.Export writes it to storage or inline;
/// DataExchange.Definition.Delete refuses referenced definitions.
/// </summary>
codeunit 96244 "DataExch Def Xfer Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "DataExch Fixture ori";
        LibraryAssert: Codeunit "Library Assert";

    [Test]
    procedure AC01_ImportFromStorage_CreatesDefinitionTree()
    var
        DataExchDef: Record "Data Exch. Def";
        ColumnDef: Record "Data Exch. Column Def";
        FieldMapping: Record "Data Exch. Field Mapping";
        MockState: Codeunit "Storage Mock State";
        Request: JsonObject;
        Response: JsonObject;
        DataObject: JsonObject;
        DefCode: Code[20];
        Xml: Text;
    begin
        // [SCENARIO] AC01: the XML of a Generic Import definition in storage installs the definition with lines, columns and mappings.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(1);
        Xml := ExportInline(DefCode);
        MockState.PutFile('defs/ac01.xml', Xml);
        DataExchDef.Get(DefCode);
        DataExchDef.Delete(true);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'defs/ac01.xml');

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Import", Request);

        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'AC01 status. ' + Fixture.ReadText(Response, 'error'));
        DataObject := Fixture.Data(Response);
        LibraryAssert.AreEqual(1, Fixture.ReadArray(DataObject, 'codes').Count(), 'AC01 one code.');
        LibraryAssert.AreEqual(1, Fixture.ReadInt(DataObject, 'lineDefs'), 'AC01 one line definition.');
        LibraryAssert.AreEqual(1, Fixture.ReadInt(DataObject, 'mappings'), 'AC01 one mapping.');
        LibraryAssert.IsTrue(DataExchDef.Get(DefCode), 'AC01 definition installed.');
        LibraryAssert.AreEqual(1, DataExchDef."Header Lines", 'AC01 header lines kept.');
        ColumnDef.SetRange("Data Exch. Def Code", DefCode);
        LibraryAssert.AreEqual(3, ColumnDef.Count(), 'AC01 three columns.');
        FieldMapping.SetRange("Data Exch. Def Code", DefCode);
        LibraryAssert.AreEqual(3, FieldMapping.Count(), 'AC01 three field mappings.');
    end;

    [Test]
    procedure AC02_ExistingCode_RefusedUnlessOverwrite()
    var
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
        Xml: Text;
    begin
        // [SCENARIO] AC02: an existing code is refused with overwrite false and replaced with overwrite true.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        Xml := ExportInline(DefCode);
        Request.Add('contentBase64', Xml);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Import", Request);
        Fixture.AssertRefusal(Response, 'PreconditionFailed', 'overwrite');

        Request.Add('overwrite', true);
        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Import", Request);
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'AC02 overwrite status. ' + Fixture.ReadText(Response, 'error'));
        LibraryAssert.AreEqual(1, Fixture.ReadArray(Fixture.Data(Response), 'overwritten').Count(), 'AC02 reports the replaced code.');
    end;

    [Test]
    procedure AC03_ExportToStorage_ReimportUnderNewCodeEqualsOriginal()
    var
        Original: Record "Data Exch. Def";
        Copy: Record "Data Exch. Def";
        MockState: Codeunit "Storage Mock State";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
        CopyCode: Code[20];
    begin
        // [SCENARIO] AC03: Definition.Export to storage, then Definition.Import under a new code equals the original.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(1);
        CopyCode := Fixture.NewCode('DXC');
        Request.Add('code', DefCode);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('folderPath', 'defs');
        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Export", Request);
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'AC03 export status. ' + Fixture.ReadText(Response, 'error'));
        LibraryAssert.AreEqual('defs/' + DefCode + '.xml', Fixture.ReadText(Fixture.Data(Response), 'path'), 'AC03 default file name.');
        LibraryAssert.IsTrue(MockState.HasFile('defs/' + DefCode + '.xml'), 'AC03 file in storage.');

        Clear(Request);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'defs/' + DefCode + '.xml');
        Request.Add('newCode', CopyCode);
        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Import", Request);
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'AC03 import status. ' + Fixture.ReadText(Response, 'error'));

        Original.Get(DefCode);
        Copy.Get(CopyCode);
        LibraryAssert.AreEqual(Original.Name, Copy.Name, 'AC03 name.');
        LibraryAssert.AreEqual(Original.Type, Copy.Type, 'AC03 type.');
        LibraryAssert.AreEqual(Original."Reading/Writing XMLport", Copy."Reading/Writing XMLport", 'AC03 reader.');
        LibraryAssert.AreEqual(Original."Header Lines", Copy."Header Lines", 'AC03 header lines.');
        LibraryAssert.AreEqual(ChildCount(Database::"Data Exch. Line Def", DefCode), ChildCount(Database::"Data Exch. Line Def", CopyCode), 'AC03 line definitions.');
        LibraryAssert.AreEqual(ChildCount(Database::"Data Exch. Column Def", DefCode), ChildCount(Database::"Data Exch. Column Def", CopyCode), 'AC03 columns.');
        LibraryAssert.AreEqual(ChildCount(Database::"Data Exch. Mapping", DefCode), ChildCount(Database::"Data Exch. Mapping", CopyCode), 'AC03 mappings.');
        LibraryAssert.AreEqual(ChildCount(Database::"Data Exch. Field Mapping", DefCode), ChildCount(Database::"Data Exch. Field Mapping", CopyCode), 'AC03 field mappings.');
    end;

    [Test]
    procedure ImportFromUpload_ConsumesSession()
    var
        DataExchDef: Record "Data Exch. Def";
        Session: Record "Storage Upload Session ori";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
        CopyCode: Code[20];
        UploadId: Text;
        UploadGuid: Guid;
    begin
        // [SCENARIO] A complete chunked upload installs the definition and the session is committed.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        CopyCode := Fixture.NewCode('DXU');
        UploadId := BeginAndAppend('def.xml', ExportInline(DefCode));
        Request.Add('uploadId', UploadId);
        Request.Add('newCode', CopyCode);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Import", Request);

        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Upload status. ' + Fixture.ReadText(Response, 'error'));
        LibraryAssert.IsTrue(DataExchDef.Get(CopyCode), 'Installed under the new code.');
        Evaluate(UploadGuid, UploadId);
        Session.Get(UploadGuid);
        LibraryAssert.AreEqual(Session.Status::Committed, Session.Status, 'Session committed.');
    end;

    [Test]
    procedure MalformedXml_RefusedWithoutWrite()
    var
        DataExchDef: Record "Data Exch. Def";
        Request: JsonObject;
        BeforeCount: Integer;
    begin
        // [SCENARIO] Content that is not definition XML is refused and nothing is installed.
        BeforeCount := DataExchDef.Count();
        Request.Add('contentBase64', Fixture.Encode('not xml at all'));
        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Import", Request), 'InvalidParameterFormat', 'contentBase64');
        Clear(Request);
        Request.Add('contentBase64', Fixture.Encode('<root></root>'));
        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Import", Request), 'InvalidParameter', 'contentBase64');
        LibraryAssert.AreEqual(BeforeCount, DataExchDef.Count(), 'Nothing is installed.');
    end;

    [Test]
    procedure NoSource_And_TwoSources_Refused()
    var
        Request: JsonObject;
    begin
        // [SCENARIO] Exactly one source is required.
        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Import", Request), 'MissingParameter', 'storageCode');
        Request.Add('contentBase64', Fixture.Encode('<root/>'));
        Request.Add('uploadId', Format(CreateGuid(), 0, 4));
        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Import", Request), 'InvalidParameter', 'storageCode');
    end;

    [Test]
    procedure DefinitionExport_InlineReturnsXml()
    var
        MockState: Codeunit "Storage Mock State";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
        Xml: Text;
    begin
        // [SCENARIO] Definition.Export inline returns the definition XML beside the header.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        Request.Add('code', DefCode);
        Request.Add('inline', true);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Export", Request);

        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Status. ' + Fixture.ReadText(Response, 'error'));
        LibraryAssert.AreEqual(DefCode, Fixture.ReadText(Fixture.Data(Response), 'code'), 'The header is inside data.');
        Xml := Fixture.Decode(Fixture.ReadText(Fixture.Data(Response), 'contentBase64'));
        LibraryAssert.IsTrue(Xml.Contains('DataExchDef'), 'The XML carries the definition.');
        LibraryAssert.IsTrue(Xml.Contains(DefCode), 'The XML carries the code.');
        LibraryAssert.AreEqual(0, MockState.GetWriteCalls(), 'Inline-only export never writes storage.');
        LibraryAssert.IsFalse(Response.Contains('storageCode') or Response.Contains('path'), 'Inline-only export has no storage destination.');
    end;

    /// <summary>Omitting delivery parameters returns exactly the header inside data and does not write storage.</summary>
    [Test]
    procedure DefinitionExport_NoDeliveryReturnsOnlyHeader()
    var
        MockState: Codeunit "Storage Mock State";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        Request.Add('code', DefCode);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Export", Request);

        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Header-only export succeeds.');
        LibraryAssert.AreEqual(2, Response.Keys().Count(), 'Only status and data are returned.');
        LibraryAssert.AreEqual(3, Fixture.Data(Response).Keys().Count(), 'Data contains only code, name and type.');
        LibraryAssert.AreEqual(DefCode, Fixture.ReadText(Fixture.Data(Response), 'code'), 'The selected header is returned.');
        LibraryAssert.IsTrue(Fixture.Data(Response).Contains('name') and Fixture.Data(Response).Contains('type'), 'The complete header is returned.');
        LibraryAssert.AreEqual(0, MockState.GetWriteCalls(), 'Header-only export never writes storage.');
        LibraryAssert.AreEqual(0, MockState.FilePaths().Count(), 'No file was created.');
    end;

    /// <summary>Combining inline and storage replaces an existing file with exactly the returned XML.</summary>
    [Test]
    procedure DefinitionExport_BothDestinationsOverwriteSameXml()
    var
        MockState: Codeunit "Storage Mock State";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
        ContentBase64: Text;
    begin
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        MockState.PutFile('definition.xml', Fixture.Encode('previous file'));
        Request.Add('code', DefCode);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'definition.xml');
        Request.Add('inline', true);
        Request.Add('overwrite', true);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Export", Request);

        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Combined export succeeds.');
        LibraryAssert.AreEqual(DefCode, Fixture.ReadText(Fixture.Data(Response), 'code'), 'The header is retained.');
        LibraryAssert.AreEqual(Fixture.StorageCode(), Fixture.ReadText(Fixture.Data(Response), 'storageCode'), 'The destination is returned.');
        LibraryAssert.AreEqual('definition.xml', Fixture.ReadText(Fixture.Data(Response), 'path'), 'The explicit path is returned.');
        ContentBase64 := Fixture.ReadText(Fixture.Data(Response), 'contentBase64');
        LibraryAssert.IsTrue(Fixture.Decode(ContentBase64).Contains(DefCode), 'The returned XML contains the seeded definition.');
        LibraryAssert.AreEqual(ContentBase64, MockState.GetFileContent('definition.xml'), 'Existing storage content is replaced by the returned XML.');
        LibraryAssert.AreEqual(1, MockState.GetWriteCalls(), 'Exactly one connector write occurs.');
    end;

    /// <summary>Discovery classifies the storage-capable type as Inbound with irreversible writes and an optional header-only mode.</summary>
    [Test]
    procedure DefinitionExport_ContractDescribesAllModesAndEffects()
    var
        Implementation: Codeunit "DataExch Def Export Impl ori";
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        Response: JsonObject;
        Parameters: JsonArray;
        Overview: Text;
        Notes: Text;
        ParametersText: Text;
        ResponseText: Text;
        SavedLanguageId: Integer;
    begin
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(1033);
        Contract := Implementation;
        Contract.GetEffect(Effect);
        Contract.GetParameters(Parameters);
        Contract.GetResponse(Response);
        Contract.GetOverview(Overview);
        Contract.GetNotes(Notes);
        GlobalLanguage(SavedLanguageId);

        LibraryAssert.AreEqual("Msg Direction ori"::Inbound, Implementation.GetMessageDirection(), 'The type can write external storage.');
        LibraryAssert.AreEqual('irreversible', Fixture.ReadText(Effect, 'effect'), 'The strongest supported effect includes overwrites.');
        LibraryAssert.IsTrue(Fixture.ReadText(Effect, 'changes').Contains('refuses an existing file unless overwrite is true'), 'The overwrite effect is explicit.');
        LibraryAssert.IsTrue(Fixture.ReadText(Effect, 'changes').Contains('Header-only and inline-only requests read'), 'Read-only modes are explicit.');
        LibraryAssert.IsTrue(Overview.Contains('by default') and Overview.Contains('contentBase64') and Overview.Contains('storageCode'), 'Overview covers all three modes.');
        LibraryAssert.IsTrue(Notes.Contains('header only') and Notes.Contains('not rolled back'), 'Notes cover the default and external write boundary.');
        Parameters.WriteTo(ParametersText);
        Response.WriteTo(ResponseText);
        LibraryAssert.IsTrue(ParametersText.Contains('Omit all delivery parameters for the header only'), 'Parameters permit the shipped header-only request.');
        LibraryAssert.IsTrue(ResponseText.Contains('omitted for header-only or inline-only requests'), 'Response describes optional storage output.');
        LibraryAssert.IsFalse(ParametersText.Contains('Send it, or inline true, or both'), 'Parameters do not falsely require XML delivery.');
    end;

    [Test]
    procedure DefinitionDelete_RefusedForPayrollImportFormat()
    var
        DataExchDef: Record "Data Exch. Def";
        GeneralLedgerSetup: Record "General Ledger Setup";
        Request: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] AC04: a definition that the General Ledger Setup names as payroll import format cannot be deleted.
        DefCode := Fixture.CreateBareDefinition("Data Exchange Definition Type"::"Payroll Import");
        if not GeneralLedgerSetup.Get() then
            GeneralLedgerSetup.Insert();
        GeneralLedgerSetup."Payroll Trans. Import Format" := DefCode;
        GeneralLedgerSetup.Modify();
        Request.Add('code', DefCode);

        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Delete", Request), 'PreconditionFailed', 'code');
        LibraryAssert.IsTrue(DataExchDef.Get(DefCode), 'The definition stays.');
    end;

    [Test]
    procedure DataRecordsSet_BlocksDefinitionAndEntryTables()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // [SCENARIO] The generic data API cannot write the tables the Data Exchange types own.
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Def", false), 'Definitions are restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Field Mapping", false), 'Field mappings are restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Field", false), 'Parsed fields are restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"DataExch Entry Link ori", false), 'Entry markers are restricted.');
    end;

    local procedure ExportInline(DefCode: Code[20]) ContentBase64: Text
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('code', DefCode);
        Request.Add('inline', true);
        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Definition.Export", Request);
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Definition.Export succeeds. ' + Fixture.ReadText(Response, 'error'));
        ContentBase64 := Fixture.ReadText(Fixture.Data(Response), 'contentBase64');
    end;

    local procedure BeginAndAppend(FileName: Text; ContentBase64: Text) UploadId: Text
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('fileName', FileName);
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Upload.Begin", Request);
        UploadId := Fixture.ReadText(Fixture.Data(Response), 'uploadId');
        Clear(Request);
        Request.Add('uploadId', UploadId);
        Request.Add('sequence', 1);
        Request.Add('contentBase64', ContentBase64);
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Upload.Append", Request);
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Append succeeds.');
    end;

    local procedure ChildCount(TableId: Integer; DefCode: Code[20]): Integer
    var
        ChildRef: RecordRef;
        DefCodeRef: FieldRef;
    begin
        ChildRef.Open(TableId);
        DefCodeRef := ChildRef.Field(1);
        DefCodeRef.SetRange(DefCode);
        exit(ChildRef.Count());
    end;
}
