namespace Origo.Bifrost.Attachments.Test;

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

    /// <summary>Absent notes clear stale caller output and consistently return false.</summary>
    [Test]
    procedure EntryDelete_NoNotes_ClearsCallerOutput()
    var
        EntryDelete: Codeunit "DataExch Entry Del Impl ori";
        Contract: Interface "Msg Contract ori";
        Notes: Text;
    begin
        // [GIVEN] The direct production interface; this operation has no public enum registration.
        Contract := EntryDelete;
        Notes := 'Stale caller notes';
        // [WHEN] Reading an absent notes chapter.
        LibraryAssert.IsFalse(Contract.GetNotes(Notes), 'No notes chapter is provided.');
        // [THEN] A stale output is cleared, including repeated calls and already-empty output.
        LibraryAssert.AreEqual('', Notes, 'Stale notes must not leak into a missing chapter.');
        Notes := 'Different stale notes';
        LibraryAssert.IsFalse(Contract.GetNotes(Notes), 'Repeated reads still have no notes.');
        LibraryAssert.AreEqual('', Notes, 'Repeated reads must clear caller output.');
        LibraryAssert.IsFalse(Contract.GetNotes(Notes), 'An empty input still has no notes chapter.');
        LibraryAssert.AreEqual('', Notes, 'Empty output remains empty.');
    end;

    /// <summary>Each shipped mutation resolves to its own contract implementation.</summary>
    [Test]
    procedure Scenario_AC03_MessageTypes_ResolveDistinctContracts()
    begin
        // [SCENARIO] Issue74 AC03 | Time: no date dependency | Risk: enum binding collisions.
        LibraryAssert.AreEqual(70013516, Enum::"Message Type ori"::"DataExchange.Type.Set".AsInteger(), 'Type.Set ordinal');
        LibraryAssert.AreEqual(70013522, Enum::"Message Type ori"::"DataExchange.Import.Run".AsInteger(), 'Import.Run ordinal');
        LibraryAssert.AreEqual(70013519, Enum::"Message Type ori"::"DataExchange.Export.Run".AsInteger(), 'Export.Run ordinal');
        LibraryAssert.AreEqual(70013523, Enum::"Message Type ori"::"DataExchange.Definition.Delete".AsInteger(), 'Definition.Delete ordinal');
        LibraryAssert.AreEqual(70013521, Enum::"Message Type ori"::"DataExchange.Definition.Export".AsInteger(), 'Definition.Export ordinal');
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
        LibraryAssert.AreEqual(Definition.Code, ReadText(Response, 'code'), 'Exported code');
        LibraryAssert.AreEqual(Definition.Name, ReadText(Response, 'name'), 'Exported name');
    end;

    /// <summary>An unlicensed direct Entry.Delete call refuses before changing persisted rows.</summary>
    [Test]
    procedure EntryDelete_UnlicensedArgument_PreservesEntryAndFields()
    var
        Definition: Record "Data Exch. Def";
        LineDefinition: Record "Data Exch. Line Def";
        Entry: Record "Data Exch.";
        Field: Record "Data Exch. Field";
        TempArgument: Record "Message Argument ori" temporary;
        EntryDelete: Codeunit "DataExch Entry Del Impl ori";
        Implementation: Interface "Msg Interface ori";
        Request: JsonObject;
        EntryNo: Integer;
    begin
        // [SCENARIO] PR84 unbound implementation: direct production interface, not wire/dispatch proof.
        // Time: independent of Today/WorkDate. Risk: licence precondition before deletion.
        // [GIVEN] A persisted isolated entry and field; a new argument is genuinely unlicensed.
        SeedDefinition(Definition, Definition.Type::"Generic Import");
        LineDefinition.Init();
        LineDefinition."Data Exch. Def Code" := Definition.Code;
        LineDefinition.Code := NewFixtureCode();
        LineDefinition.Name := 'Unlicensed deletion fixture';
        LineDefinition.Insert();
        Entry.Init();
        Entry."Data Exch. Def Code" := Definition.Code;
        Entry."Data Exch. Line Def Code" := LineDefinition.Code;
        Entry."File Name" := 'XPR84-unlicensed.txt';
        Entry.Insert(true);
        EntryNo := Entry."Entry No.";
        Field.InsertRec(EntryNo, 1, 1, 'Xoriginal', LineDefinition.Code);
        Field.SetRange("Data Exch. No.", EntryNo);
        LibraryAssert.AreEqual(1, Field.Count(), 'Fixture field must exist before execution.');
        TempArgument.Version := TempArgument.Version::"1.0";
        Request.Add('entryNo', EntryNo);
        TempArgument.SetRequestJson(Request);
        Implementation := EntryDelete;
        // [WHEN] The actual production implementation receives the unlicensed argument.
        asserterror Implementation.ExecuteBifrostTask(TempArgument);
        // [THEN] Licence refusal precedes every write; neither fixture row disappears.
        LibraryAssert.ExpectedError('requires a valid license');
        LibraryAssert.IsTrue(Entry.Get(EntryNo), 'Unlicensed entry must remain.');
        Field.SetRange("Data Exch. No.", EntryNo);
        LibraryAssert.AreEqual(1, Field.Count(), 'Unlicensed fields must remain.');
        Field.FindFirst();
        LibraryAssert.AreEqual('Xoriginal', Field.Value, 'Unlicensed field content must remain.');
        LibraryAssert.AreEqual(LineDefinition.Code, Field."Data Exch. Line Def Code", 'Unlicensed field relationship must remain.');
    end;

    /// <summary>An unlicensed direct Definition.Import call refuses before creating a definition.</summary>
    [Test]
    procedure DefinitionImport_UnlicensedArgument_DoesNotInsert()
    var
        Definition: Record "Data Exch. Def";
        TempArgument: Record "Message Argument ori" temporary;
        DefinitionImport: Codeunit "DataExch Def Import Impl ori";
        Implementation: Interface "Msg Interface ori";
        Request: JsonObject;
        BeforeCount: Integer;
    begin
        // [SCENARIO] PR84 unbound implementation: direct production interface, not wire/dispatch proof.
        // Time: independent of Today/WorkDate. Risk: licence precondition before XML import.
        // [GIVEN] A genuinely unlicensed argument, valid standard-exported XML and known table count.
        SeedDefinition(Definition, Definition.Type::"Generic Import");
        BeforeCount := Definition.Count();
        TempArgument.Version := TempArgument.Version::"1.0";
        Request.Add('definitionXml', ExportDefinitionXml(Definition));
        TempArgument.SetRequestJson(Request);
        Implementation := DefinitionImport;
        // [WHEN] The actual production importer receives the unlicensed argument.
        asserterror Implementation.ExecuteBifrostTask(TempArgument);
        // [THEN] The licence error with valid XML proves refusal before import.
        LibraryAssert.ExpectedError('requires a valid license');
        LibraryAssert.AreEqual(BeforeCount, Definition.Count(), 'Unlicensed import must not insert.');
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

    /// <summary>The renamed Export.Run extension still dispatches and persists the existing entry header.</summary>
    [Test]
    procedure Scenario_AC03_ExportRun_ExportHeaderIsPersisted()
    var
        Definition: Record "Data Exch. Def";
        Entry: Record "Data Exch.";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO] Issue74 AC03 | Time: no date dependency | Risk: name-only extension repair.
        // [GIVEN] A real export definition. This tests existing entry creation, not file export completion.
        SeedDefinition(Definition, Definition.Type::"Payment Export");
        Request.Add('dataExchDefCode', Definition.Code);
        Request.Add('fileName', 'XBUILD74-export.txt');
        // [WHEN] Foundation dispatches the registered Export.Run message.
        Response := Execute(Enum::"Message Type ori"::"DataExchange.Export.Run", Request);
        // [THEN] The response agrees with the newly persisted entry header.
        LibraryAssert.AreEqual('Success', ReadText(Response, 'status'), 'Export.Run status');
        LibraryAssert.IsTrue(Response.Get('entryNo', Token), 'Export response must name the persisted entry.');
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

    /// <summary>Export.Run retains the missing-file refusal without creating an entry.</summary>
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
        // [GIVEN] A real export definition and no fileName parameter.
        SeedDefinition(Definition, Definition.Type::"Payment Export");
        BeforeCount := Entry.Count();
        Request.Add('dataExchDefCode', Definition.Code);
        // [WHEN] Foundation dispatches the registered Export.Run message.
        Response := Execute(Enum::"Message Type ori"::"DataExchange.Export.Run", Request);
        // [THEN] The error leaves the entry table unchanged.
        LibraryAssert.AreEqual('Error', ReadText(Response, 'status'), 'Missing file name must fail.');
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

    local procedure ExportDefinitionXml(Definition: Record "Data Exch. Def"): Text
    var
        TempBlob: Codeunit "Temp Blob";
        DefinitionExport: XmlPort "Imp / Exp Data Exch Def & Map";
        XmlContent: BigText;
        XmlText: Text;
        XmlOutStream: OutStream;
        XmlInStream: InStream;
    begin
        Definition.SetRecFilter();
        TempBlob.CreateOutStream(XmlOutStream, TextEncoding::UTF8);
        DefinitionExport.SetTableView(Definition);
        DefinitionExport.SetDestination(XmlOutStream);
        DefinitionExport.Export();
        TempBlob.CreateInStream(XmlInStream, TextEncoding::UTF8);
        XmlContent.Read(XmlInStream);
        XmlContent.GetSubText(XmlText, 1);
        LibraryAssert.IsTrue(XmlText <> '', 'The real standard XMLport must export the fixture.');
        exit(XmlText);
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

    local procedure ReadText(Response: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(Response.Get(Name, Token), 'Response must contain ' + Name);
        exit(Token.AsValue().AsText());
    end;
}
