namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.Utilities;

/// <summary>Verifies the existing Data Exchange surface after the compilation-input repair for issue 74.</summary>
codeunit 96274 "Attachments Build Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        ExportRunSelectionTok: Label 'Runs a Generic Export definition over a table view or a list of record SystemIds and delivers the file; payment files use DataExchange.PaymentExport.Run.', Locked = true;

    /// <summary>Verifies exact English discovery text from three shipped production implementations without licence or provider fixtures.</summary>
    [Test]
    procedure Language72_Discovery_ExactEnglish()
    var
        DefinitionExport: Codeunit "DataExch Def Export Impl ori";
        ExportRun: Codeunit "DataExch Export Run Impl ori";
        TypeSet: Codeunit "DataExch Type Set Impl ori";
        Implementation: Interface "Msg Interface ori";
        Discovery: Interface "Msg Discovery ori";
        Actual: List of [Text];
        SavedLanguageId: Integer;
    begin
        // Story #72 + #74: exact source prose must translate even for unregistered direct interfaces.
        // [GIVEN] Real production implementations and the requested language.
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(1033);
        // [WHEN] Reading all three discovery texts; restore the caller language before assertions.
        Implementation := DefinitionExport;
        Discovery := DefinitionExport;
        Actual.Add(Implementation.GetDescription());
        Actual.Add(Discovery.GetKeywords());
        Actual.Add(Discovery.GetSelectionDescription());
        Implementation := ExportRun;
        Discovery := ExportRun;
        Actual.Add(Implementation.GetDescription());
        Actual.Add(Discovery.GetKeywords());
        Actual.Add(Discovery.GetSelectionDescription());
        Implementation := TypeSet;
        Discovery := TypeSet;
        Actual.Add(Implementation.GetDescription());
        Actual.Add(Discovery.GetKeywords());
        Actual.Add(Discovery.GetSelectionDescription());
        GlobalLanguage(SavedLanguageId);
        // [THEN] Exact expectations reject fallback, empty text and a wrong sibling implementation.
        LibraryAssert.AreEqual('Returns the definition header (code, name and type); optionally returns XML inline or writes it to storage.', Actual.Get(1), 'Exact English discovery text 1.');
        LibraryAssert.AreEqual('export data exchange definition, dump definition', Actual.Get(2), 'Exact English discovery text 2.');
        LibraryAssert.AreEqual('Use for the definition header by default, XML with inline true, or an XML file with storageCode and path. Both XML destinations may be requested.', Actual.Get(3), 'Exact English discovery text 3.');
        LibraryAssert.AreEqual('Exports records with a Generic Export definition and writes the file to storage or returns it inline.', Actual.Get(4), 'Exact English discovery text 4.');
        LibraryAssert.AreEqual('data exchange export, export records to file, export csv, generic export, export to storage', Actual.Get(5), 'Exact English discovery text 5.');
        LibraryAssert.AreEqual(ExportRunSelectionTok, Actual.Get(6), 'Exact English discovery text 6.');
        LibraryAssert.AreEqual('Creates or updates a Data Exchange Type and requires an import definition.', Actual.Get(7), 'Exact English discovery text 7.');
        LibraryAssert.AreEqual('data exchange type, incoming document type, set definition', Actual.Get(8), 'Exact English discovery text 8.');
        LibraryAssert.AreEqual('Wires a Data Exchange Type to an import definition.', Actual.Get(9), 'Exact English discovery text 9.');
    end;

    /// <summary>Verifies exact Icelandic discovery text from three shipped production implementations without licence or provider fixtures.</summary>
    [Test]
    procedure Language72_Discovery_ExactIcelandic()
    var
        DefinitionExport: Codeunit "DataExch Def Export Impl ori";
        ExportRun: Codeunit "DataExch Export Run Impl ori";
        TypeSet: Codeunit "DataExch Type Set Impl ori";
        Implementation: Interface "Msg Interface ori";
        Discovery: Interface "Msg Discovery ori";
        Actual: List of [Text];
        SavedLanguageId: Integer;
    begin
        // Story #72 + #74: exact source prose must translate even for unregistered direct interfaces.
        // [GIVEN] Real production implementations and the requested language.
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(1039);
        // [WHEN] Reading all three discovery texts; restore the caller language before assertions.
        Implementation := DefinitionExport;
        Discovery := DefinitionExport;
        Actual.Add(Implementation.GetDescription());
        Actual.Add(Discovery.GetKeywords());
        Actual.Add(Discovery.GetSelectionDescription());
        Implementation := ExportRun;
        Discovery := ExportRun;
        Actual.Add(Implementation.GetDescription());
        Actual.Add(Discovery.GetKeywords());
        Actual.Add(Discovery.GetSelectionDescription());
        Implementation := TypeSet;
        Discovery := TypeSet;
        Actual.Add(Implementation.GetDescription());
        Actual.Add(Discovery.GetKeywords());
        Actual.Add(Discovery.GetSelectionDescription());
        GlobalLanguage(SavedLanguageId);
        // [THEN] Exact expectations reject fallback, empty text and a wrong sibling implementation.
        LibraryAssert.AreEqual('Skilar haus skilgreiningar gagnaskipta (kóða, heiti og gerð); skilar einnig XML innfellt eða skrifar það í geymslu ef óskað er.', Actual.Get(1), 'Exact Icelandic discovery text 1.');
        LibraryAssert.AreEqual('flytja út skilgreiningu gagnaskipta, afrita skilgreiningu', Actual.Get(2), 'Exact Icelandic discovery text 2.');
        LibraryAssert.AreEqual('Notaðu fyrir haus skilgreiningar sjálfgefið, XML með inline true eða XML-skrá með storageCode og path. Biðja má um báða áfangastaði XML.', Actual.Get(3), 'Exact Icelandic discovery text 3.');
        LibraryAssert.AreEqual('Flytur út færslur með skilgreiningu fyrir almennan útflutning og skrifar skrána í geymslu eða skilar henni innfellt.', Actual.Get(4), 'Exact Icelandic discovery text 4.');
        LibraryAssert.AreEqual('útflutningur gagnaskipta, flytja færslur út í skrá, flytja út csv, almennur útflutningur, flytja út í geymslu', Actual.Get(5), 'Exact Icelandic discovery text 5.');
        // #157: caller-facing selection text must translate; only public help chapters stay English.
        LibraryAssert.AreEqual('Keyrir skilgreiningu fyrir almennan útflutning á töflusýn eða lista af SystemId-auðkennum færslna og afhendir skrána; notaðu DataExchange.PaymentExport.Run fyrir greiðsluskrár.', Actual.Get(6), 'Exact Icelandic discovery text 6.');
        LibraryAssert.AreEqual('Stofnar eða uppfærir gerð gagnaskipta og krefst innflutningsskilgreiningar.', Actual.Get(7), 'Exact Icelandic discovery text 7.');
        LibraryAssert.AreEqual('gerð gagnaskipta, gerð skjals í innleið, stilla skilgreiningu', Actual.Get(8), 'Exact Icelandic discovery text 8.');
        LibraryAssert.AreEqual('Tengir gerð gagnaskipta við innflutningsskilgreiningu.', Actual.Get(9), 'Exact Icelandic discovery text 9.');
    end;

    /// <summary>Each shipped mutation resolves to its own contract implementation.</summary>
    [Test]
    procedure Scenario_AC03_MessageTypes_ResolveDistinctContracts()
    begin
        // [SCENARIO] Issue74 AC03 | Time: no date dependency | Risk: enum binding collisions.
        LibraryAssert.AreEqual(10035164, Enum::"Message Type ori"::"DataExchange.Type.Set".AsInteger(), 'Type.Set ordinal');
        LibraryAssert.AreEqual(10035170, Enum::"Message Type ori"::"DataExchange.Import.Run".AsInteger(), 'Import.Run ordinal');
        LibraryAssert.AreEqual(10035167, Enum::"Message Type ori"::"DataExchange.Export.Run".AsInteger(), 'Export.Run ordinal');
        LibraryAssert.AreEqual(10035171, Enum::"Message Type ori"::"DataExchange.Definition.Delete".AsInteger(), 'Definition.Delete ordinal');
        LibraryAssert.AreEqual(10035169, Enum::"Message Type ori"::"DataExchange.Definition.Export".AsInteger(), 'Definition.Export ordinal');
        AssertContract(Enum::"Message Type ori"::"DataExchange.Type.Set", 'DataExchange.Type.Set');
        AssertContract(Enum::"Message Type ori"::"DataExchange.Import.Run", 'DataExchange.Import.Run');
        AssertContract(Enum::"Message Type ori"::"DataExchange.Export.Run", 'DataExchange.Export.Run');
        AssertContract(Enum::"Message Type ori"::"DataExchange.Definition.Delete", 'DataExchange.Definition.Delete');
        AssertContract(Enum::"Message Type ori"::"DataExchange.Definition.Export", 'DataExchange.Definition.Export');
    end;

    /// <summary>An import definition is bound through the public dispatcher and persisted.</summary>
    [Test]
    procedure Scenario_AC02_TypeSet_ImportDefinitionIsPersisted()
    var
        Definition: Record "Data Exch. Def";
        ExchangeType: Record "Data Exchange Type";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] A real import definition in the isolated test transaction.
        SeedDefinition(Definition, Definition.Type::"Generic Import");
        Request.Add('code', Definition.Code);
        Request.Add('dataExchDefCode', Definition.Code);
        Request.Add('description', 'Compilation repair test');

        // [WHEN] The previously uncompilable message implementation is dispatched.
        Response := Execute(Enum::"Message Type ori"::"DataExchange.Type.Set", Request);

        // [THEN] The successful answer agrees with the persisted binding.
        LibraryAssert.AreEqual('Success', ReadText(Response, 'status'), 'Type.Set status');
        ExchangeType.SetLoadFields("Data Exch. Def. Code", Description);
        LibraryAssert.IsTrue(ExchangeType.Get(Definition.Code), 'Type.Set must persist a type.');
        LibraryAssert.AreEqual(Definition.Code, ExchangeType."Data Exch. Def. Code", 'Stored definition');
        LibraryAssert.AreEqual('Compilation repair test', ExchangeType.Description, 'Stored description');
    end;

    /// <summary>Missing required input remains a refusal without inserting an exchange type.</summary>
    [Test]
    procedure Scenario_AC02_TypeSet_MissingDefinitionDoesNotWrite()
    var
        ExchangeType: Record "Data Exchange Type";
        Request: JsonObject;
        Response: JsonObject;
        TypeCode: Code[20];
    begin
        // [GIVEN] The definition parameter is absent.
        TypeCode := NewFixtureCode();
        ExchangeType.SetRange(Code, TypeCode);
        LibraryAssert.IsTrue(ExchangeType.IsEmpty(), 'Fixture type must be absent before the request.');
        Request.Add('code', TypeCode);

        // [WHEN] The existing error path is dispatched.
        Response := Execute(Enum::"Message Type ori"::"DataExchange.Type.Set", Request);

        // [THEN] No successful result or partially created exchange type is allowed.
        LibraryAssert.AreEqual('Error', ReadText(Response, 'status'), 'Missing definition must fail.');
        ExchangeType.SetRange(Code, TypeCode);
        LibraryAssert.IsTrue(ExchangeType.IsEmpty(), 'Missing definition must not insert a type.');
    end;

    /// <summary>The existing import-only restriction still rejects an export definition.</summary>
    [Test]
    procedure Scenario_AC02_TypeSet_ExportDefinitionDoesNotWrite()
    var
        Definition: Record "Data Exch. Def";
        ExchangeType: Record "Data Exchange Type";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] A definition of the unsupported direction.
        SeedDefinition(Definition, Definition.Type::"Payment Export");
        Request.Add('code', Definition.Code);
        Request.Add('dataExchDefCode', Definition.Code);

        // [WHEN] The existing direction guard runs.
        Response := Execute(Enum::"Message Type ori"::"DataExchange.Type.Set", Request);

        // [THEN] The refusal leaves the type table unchanged.
        LibraryAssert.AreEqual('Error', ReadText(Response, 'status'), 'Export definition must fail.');
        ExchangeType.SetRange(Code, Definition.Code);
        LibraryAssert.IsTrue(ExchangeType.IsEmpty(), 'Export definition must not insert a type.');
    end;

    /// <summary>Definition.Export reads the real Microsoft definition table and returns its header.</summary>
    [Test]
    procedure Scenario_AC02_DefinitionExport_ReturnsExistingHeader()
    var
        Definition: Record "Data Exch. Def";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] A definition with known header fields.
        SeedDefinition(Definition, Definition.Type::"Generic Import");
        Request.Add('code', Definition.Code);

        // [WHEN] The existing header-export behavior is dispatched.
        Response := Execute(Enum::"Message Type ori"::"DataExchange.Definition.Export", Request);

        // [THEN] The answer contains the actual stored header; no roadmap XML export is implied.
        LibraryAssert.AreEqual('Success', ReadText(Response, 'status'), 'Definition.Export status');
        LibraryAssert.AreEqual(Definition.Code, ReadText(SuccessData(Response), 'code'), 'Exported code');
        LibraryAssert.AreEqual(Definition.Name, ReadText(SuccessData(Response), 'name'), 'Exported name');
        // The type is the enum name, never Format() of the enum (#82).
        LibraryAssert.AreEqual('Generic Import', ReadText(SuccessData(Response), 'type'), 'Exported type name');
    end;

    /// <summary>The relocated Definition.Delete ordinal still dispatches and removes a persisted header.</summary>
    [Test]
    procedure Scenario_AC03_DefinitionDelete_UnusedHeaderIsRemoved()
    var
        Definition: Record "Data Exch. Def";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] Issue74 AC03 | Time: no date dependency | Risk: relocated message binding.
        // [GIVEN] A real unused definition in the isolated test transaction.
        SeedDefinition(Definition, Definition.Type::"Generic Import");
        Request.Add('code', Definition.Code);
        // [WHEN] Foundation dispatches the registered Definition.Delete message.
        Response := Execute(Enum::"Message Type ori"::"DataExchange.Definition.Delete", Request);
        // [THEN] The successful response agrees with persisted header removal.
        LibraryAssert.AreEqual('Success', ReadText(Response, 'status'), 'Definition.Delete status');
        LibraryAssert.IsFalse(Definition.Get(Definition.Code), 'Unused definition must be deleted.');
    end;

    /// <summary>The relocated Definition.Delete ordinal still refuses a referenced definition.</summary>
    [Test]
    procedure Scenario_AC03_DefinitionDelete_ReferencedHeaderIsPreserved()
    var
        Definition: Record "Data Exch. Def";
        ExchangeType: Record "Data Exchange Type";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] Issue74 AC03 | Time: no date dependency | Risk: reference protection.
        // [GIVEN] A persisted definition referenced by a persisted Data Exchange Type.
        SeedDefinition(Definition, Definition.Type::"Generic Import");
        ExchangeType.Init();
        ExchangeType.Code := Definition.Code;
        ExchangeType."Data Exch. Def. Code" := Definition.Code;
        ExchangeType.Insert();
        Request.Add('code', Definition.Code);
        // [WHEN] Foundation dispatches the registered Definition.Delete message.
        Response := Execute(Enum::"Message Type ori"::"DataExchange.Definition.Delete", Request);
        // [THEN] Both rows and their relationship remain after the refusal.
        LibraryAssert.AreEqual('Error', ReadText(Response, 'status'), 'Referenced definition must fail.');
        LibraryAssert.IsTrue(Definition.Get(Definition.Code), 'Referenced definition must remain.');
        LibraryAssert.IsTrue(ExchangeType.Get(Definition.Code), 'Referencing type must remain.');
        LibraryAssert.AreEqual(Definition.Code, ExchangeType."Data Exch. Def. Code", 'Reference must remain.');
    end;

    /// <summary>Definition.Delete reports an error for a missing header without altering the table.</summary>
    [Test]
    procedure Scenario_AC03_DefinitionDelete_MissingHeaderDoesNotWrite()
    var
        Definition: Record "Data Exch. Def";
        Request: JsonObject;
        Response: JsonObject;
        BeforeCount: Integer;
        DefinitionCode: Code[20];
    begin
        // [SCENARIO] Issue74 AC03 | Time: no date dependency | Risk: missing-record refusal.
        // [GIVEN] A key absent from the definition table.
        DefinitionCode := NewFixtureCode();
        LibraryAssert.IsFalse(Definition.Get(DefinitionCode), 'Fixture key must be absent.');
        BeforeCount := Definition.Count();
        Request.Add('code', DefinitionCode);
        // [WHEN] Foundation dispatches the registered message.
        Response := Execute(Enum::"Message Type ori"::"DataExchange.Definition.Delete", Request);
        // [THEN] The refusal leaves the definition count unchanged.
        LibraryAssert.AreEqual('Error', ReadText(Response, 'status'), 'Missing definition must fail.');
        LibraryAssert.AreEqual(BeforeCount, Definition.Count(), 'No definition may be changed.');
    end;

    /// <summary>The renamed Export.Run extension still dispatches and persists the export entry with its file name.</summary>
    [Test]
    procedure Scenario_AC03_ExportRun_ExportHeaderIsPersisted()
    var
        Definition: Record "Data Exch. Def";
        Entry: Record "Data Exch.";
        Customer: Record Customer;
        Fixture: Codeunit "DataExch Fixture ori";
        CustomerNos: List of [Code[20]];
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO] Issue74 AC03 | Time: no date dependency | Risk: name-only extension repair.
        // [GIVEN] A real Generic Export definition and one customer (#25: Export.Run exports Generic Export only).
        Definition.Get(Fixture.CreateExportDefinition());
        CustomerNos := Fixture.CreateCustomers(1, 'XBUILD74');
        Customer.Get(CustomerNos.Get(1));
        Request.Add('dataExchDefCode', Definition.Code);
        Request.Add('fileName', 'XBUILD74-export.txt');
        Request.Add('tableId', Database::Customer);
        Request.Add('tableView', 'WHERE(No.=FILTER(' + Customer."No." + '))');
        Request.Add('inline', true);
        // [WHEN] Foundation dispatches the registered Export.Run message.
        Response := Execute(Enum::"Message Type ori"::"DataExchange.Export.Run", Request);
        // [THEN] The response agrees with the newly persisted entry.
        LibraryAssert.AreEqual('Success', ReadText(Response, 'status'), 'Export.Run status');
        LibraryAssert.IsTrue(SuccessData(Response).Get('entryNo', Token), 'Export response must name the persisted entry.');
        LibraryAssert.IsTrue(Entry.Get(Token.AsValue().AsInteger()), 'Export entry must exist.');
        LibraryAssert.AreEqual(Definition.Code, Entry."Data Exch. Def Code", 'Entry definition');
        LibraryAssert.AreEqual('XBUILD74-export.txt', Entry."File Name", 'Entry file name');
    end;

    /// <summary>Export.Run retains its import-direction refusal without creating an entry.</summary>
    [Test]
    procedure Scenario_AC03_ExportRun_ImportDefinitionDoesNotWrite()
    var
        Definition: Record "Data Exch. Def";
        Entry: Record "Data Exch.";
        Request: JsonObject;
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // [SCENARIO] Issue74 AC03 | Time: no date dependency | Risk: direction refusal.
        // [GIVEN] A real definition of the unsupported import direction.
        SeedDefinition(Definition, Definition.Type::"Generic Import");
        BeforeCount := Entry.Count();
        Request.Add('dataExchDefCode', Definition.Code);
        Request.Add('fileName', 'XBUILD74-export.txt');
        // [WHEN] Foundation dispatches the registered Export.Run message.
        Response := Execute(Enum::"Message Type ori"::"DataExchange.Export.Run", Request);
        // [THEN] The error leaves the entry table unchanged.
        LibraryAssert.AreEqual('Error', ReadText(Response, 'status'), 'Import definition must fail.');
        LibraryAssert.AreEqual(BeforeCount, Entry.Count(), 'Refused export must not insert.');
    end;

    /// <summary>Export.Run refuses a request without records or delivery without creating an entry.</summary>
    [Test]
    procedure Scenario_AC03_ExportRun_MissingFileNameDoesNotWrite()
    var
        Definition: Record "Data Exch. Def";
        Entry: Record "Data Exch.";
        Request: JsonObject;
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // [SCENARIO] Issue74 AC03 | Time: no date dependency | Risk: required parameter.
        // [GIVEN] A real Generic Export definition and neither records nor a delivery (fileName is optional since #25).
        SeedDefinition(Definition, Definition.Type::"Generic Export");
        BeforeCount := Entry.Count();
        Request.Add('dataExchDefCode', Definition.Code);
        // [WHEN] Foundation dispatches the registered Export.Run message.
        Response := Execute(Enum::"Message Type ori"::"DataExchange.Export.Run", Request);
        // [THEN] The error leaves the entry table unchanged.
        LibraryAssert.AreEqual('Error', ReadText(Response, 'status'), 'A request without records and delivery must fail.');
        LibraryAssert.AreEqual(BeforeCount, Entry.Count(), 'Incomplete export must not insert.');
    end;

    local procedure SeedDefinition(var Definition: Record "Data Exch. Def"; DefinitionType: Enum "Data Exchange Definition Type")
    begin
        Definition.Init();
        Definition.Code := NewFixtureCode();
        Definition.Name := 'Compilation repair test';
        Definition.Type := DefinitionType;
        Definition.Insert();
    end;

    local procedure NewFixtureCode(): Code[20]
    begin
        // Dispatcher execution can retain records between methods; every call owns a fresh key.
        exit(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20));
    end;

    local procedure AssertContract(MessageType: Enum "Message Type ori"; ExpectedName: Text)
    var
        Contract: Interface "Msg Contract ori";
        Envelope: JsonObject;
    begin
        Contract := MessageType;
        LibraryAssert.IsTrue(Contract.GetEnvelope(Envelope), 'Message must declare its envelope.');
        LibraryAssert.AreEqual(ExpectedName, ReadText(Envelope, 'messageType'), 'Enum resolves to the intended implementation.');
    end;

    local procedure Execute(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        MessageVersion: Enum "Message Version ori";
        ContentType: Text[100];
        RequestText: Text;
        ResponseText: Text;
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        LibraryAssert.IsTrue(Response.ReadFrom(ResponseText), 'Dispatcher must return JSON.');
    end;

    local procedure SuccessData(Response: JsonObject): JsonObject
    var
        Token: JsonToken;
    begin
        LibraryAssert.AreEqual('Success', ReadText(Response, 'status'), 'Success envelope required.');
        LibraryAssert.IsTrue(Response.Get('data', Token), 'Success data required.');
        LibraryAssert.IsTrue(Token.IsObject(), 'Success data must be an object.');
        exit(Token.AsObject());
    end;

    local procedure ReadText(Response: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(Response.Get(Name, Token), 'Response must contain ' + Name);
        exit(Token.AsValue().AsText());
    end;
}
