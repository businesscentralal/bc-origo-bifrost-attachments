namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Bank.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.TestLibraries.Utilities;

/// <summary>Story 82: real dispatched refusal, state readback and caller-transaction regressions.</summary>
codeunit 96226 "DataExch Refusal82 Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    EventSubscriberInstance = Manual;

    var
        LibraryAssert: Codeunit "Library Assert";
        FailInsert: Boolean;
        FailDelete: Boolean;
        FailTypeModify: Boolean;
        FailureDefinitionCode: Code[20];

    /// <summary>A valid request retains Accepted and creates only the header.</summary>
    [Test]
    procedure Scenario_AC03_GenericImport_CreatesOnlyHeader()
    var
        DataExch: Record "Data Exch.";
        DefinitionCode: Code[20];
        Response: JsonObject;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A permitted definition and a deliberately unconfigured storage code.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        // [WHEN] The registered import message is dispatched.
        Response := DispatchImport(DefinitionCode, 'XUNCONFIGURED', 'invoices/X82.csv');
        // [THEN] The header exists, without any imported file content or storage resolution.
        AssertText(Response, 'status', 'Accepted');
        AssertText(Response, 'dataExchDefCode', DefinitionCode);
        DataExch.Get(IntegerProperty(Response, 'entryNo'));
        LibraryAssert.AreEqual(DefinitionCode, DataExch."Data Exch. Def Code", 'Wrong definition on the created header.');
        LibraryAssert.AreEqual('', DataExch."File Name", 'Import must remain header-only.');
        DataExch.CalcFields("File Content");
        LibraryAssert.IsFalse(DataExch."File Content".HasValue(), 'Import must not read provider content.');
        LibraryAssert.AreEqual(1, EntryCount(DefinitionCode), 'Exactly one header must be created.');
    end;

    /// <summary>A valid request retains Accepted and creates only the header.</summary>
    [Test]
    procedure Scenario_AC03_PayrollImport_CreatesOnlyHeader()
    var
        DataExch: Record "Data Exch.";
        DefinitionCode: Code[20];
        Response: JsonObject;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A permitted definition and a deliberately unconfigured storage code.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Payroll Import");
        // [WHEN] The registered import message is dispatched.
        Response := DispatchImport(DefinitionCode, 'XUNCONFIGURED', 'invoices/X82.csv');
        // [THEN] The header exists, without any imported file content or storage resolution.
        AssertText(Response, 'status', 'Accepted');
        AssertText(Response, 'dataExchDefCode', DefinitionCode);
        DataExch.Get(IntegerProperty(Response, 'entryNo'));
        LibraryAssert.AreEqual(DefinitionCode, DataExch."Data Exch. Def Code", 'Wrong definition on the created header.');
        LibraryAssert.AreEqual('', DataExch."File Name", 'Import must remain header-only.');
        DataExch.CalcFields("File Content");
        LibraryAssert.IsFalse(DataExch."File Content".HasValue(), 'Import must not read provider content.');
        LibraryAssert.AreEqual(1, EntryCount(DefinitionCode), 'Exactly one header must be created.');
    end;

    /// <summary>Missing fields all have complete error details.</summary>
    [Test]
    procedure Scenario_AC01_AbsentFields_CollectsAllThree()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] No request fields and the current entry count.
        BeforeCount := EntryCount('');
        // [WHEN] A registered import is dispatched.
        Response := Dispatch("Message Type ori"::"DataExchange.Import.Run", '{}');
        // [THEN] All three fields refuse without writing a header.
        AssertThreeInputErrors(Response, 'MissingParameter');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Missing input must not write.');
    end;

    /// <summary>All independently invalid fields are reported before writes.</summary>
    [Test]
    procedure Scenario_AC02_WrongTypes_CollectsAllWithoutWrite()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] Three independent bad fields.
        BeforeCount := EntryCount('');
        // [WHEN] The real registered implementation receives the payload.
        Response := Dispatch("Message Type ori"::"DataExchange.Import.Run", '{"dataExchDefCode":3,"storageCode":true,"path":[]}');
        // [THEN] Every field has a complete refusal and the table is unchanged.
        AssertThreeInputErrors(Response, 'InvalidParameterFormat');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Invalid input must not write.');
    end;

    /// <summary>All independently invalid fields are reported before writes.</summary>
    [Test]
    procedure Scenario_AC02_NullFields_CollectsAllWithoutWrite()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] Three independent bad fields.
        BeforeCount := EntryCount('');
        // [WHEN] The real registered implementation receives the payload.
        Response := Dispatch("Message Type ori"::"DataExchange.Import.Run", '{"dataExchDefCode":null,"storageCode":null,"path":null}');
        // [THEN] Every field has a complete refusal and the table is unchanged.
        AssertThreeInputErrors(Response, 'InvalidParameterFormat');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Invalid input must not write.');
    end;

    /// <summary>All independently invalid fields are reported before writes.</summary>
    [Test]
    procedure Scenario_AC02_ObjectFields_CollectsAllWithoutWrite()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] Three independent bad fields.
        BeforeCount := EntryCount('');
        // [WHEN] The real registered implementation receives the payload.
        Response := Dispatch("Message Type ori"::"DataExchange.Import.Run", '{"dataExchDefCode":{},"storageCode":[],"path":{}}');
        // [THEN] Every field has a complete refusal and the table is unchanged.
        AssertThreeInputErrors(Response, 'InvalidParameterFormat');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Invalid input must not write.');
    end;

    /// <summary>All independently invalid fields are reported before writes.</summary>
    [Test]
    procedure Scenario_AC02_EmptyFields_CollectsAllWithoutWrite()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] Three independent bad fields.
        BeforeCount := EntryCount('');
        // [WHEN] The real registered implementation receives the payload.
        Response := Dispatch("Message Type ori"::"DataExchange.Import.Run", '{"dataExchDefCode":"","storageCode":"","path":""}');
        // [THEN] Every field has a complete refusal and the table is unchanged.
        AssertThreeInputErrors(Response, 'MissingParameter');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Invalid input must not write.');
    end;

    /// <summary>Noncanonical or overlong codes refuse before normalization.</summary>
    [Test]
    procedure Scenario_AC02_Lowercase_RefusesRawCode()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A raw key that Code20 conversion would change.
        BeforeCount := EntryCount('');
        // [WHEN] It is used for all applicable code fields.
        Response := DispatchImport('xlower', 'xlower', 'X82.csv');
        // [THEN] Both independent code errors are collected, with original spelling.
        AssertRefusal(Response, 'InvalidParameterFormat', 'dataExchDefCode', 'xlower');
        AssertRefusal(Response, 'InvalidParameterFormat', 'storageCode', 'xlower');
        LibraryAssert.AreEqual(2, ErrorCount(Response), 'Both codes must refuse.');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Invalid codes must not write.');
        Response := DispatchDelete('xlower');
        AssertRefusal(Response, 'InvalidParameterFormat', 'code', 'xlower');
    end;

    /// <summary>Noncanonical or overlong codes refuse before normalization.</summary>
    [Test]
    procedure Scenario_AC02_MixedCase_RefusesRawCode()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A raw key that Code20 conversion would change.
        BeforeCount := EntryCount('');
        // [WHEN] It is used for all applicable code fields.
        Response := DispatchImport('XmIxEd', 'XmIxEd', 'X82.csv');
        // [THEN] Both independent code errors are collected, with original spelling.
        AssertRefusal(Response, 'InvalidParameterFormat', 'dataExchDefCode', 'XmIxEd');
        AssertRefusal(Response, 'InvalidParameterFormat', 'storageCode', 'XmIxEd');
        LibraryAssert.AreEqual(2, ErrorCount(Response), 'Both codes must refuse.');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Invalid codes must not write.');
        Response := DispatchDelete('XmIxEd');
        AssertRefusal(Response, 'InvalidParameterFormat', 'code', 'XmIxEd');
    end;

    /// <summary>Noncanonical or overlong codes refuse before normalization.</summary>
    [Test]
    procedure Scenario_AC02_UnicodeCase_RefusesRawCode()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A raw key that Code20 conversion would change.
        BeforeCount := EntryCount('');
        // [WHEN] It is used for all applicable code fields.
        Response := DispatchImport('Xþór', 'Xþór', 'X82.csv');
        // [THEN] Both independent code errors are collected, with original spelling.
        AssertRefusal(Response, 'InvalidParameterFormat', 'dataExchDefCode', 'Xþór');
        AssertRefusal(Response, 'InvalidParameterFormat', 'storageCode', 'Xþór');
        LibraryAssert.AreEqual(2, ErrorCount(Response), 'Both codes must refuse.');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Invalid codes must not write.');
        Response := DispatchDelete('Xþór');
        AssertRefusal(Response, 'InvalidParameterFormat', 'code', 'Xþór');
    end;

    /// <summary>Noncanonical or overlong codes refuse before normalization.</summary>
    [Test]
    procedure Scenario_AC02_LeadingSpace_RefusesRawCode()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A raw key that Code20 conversion would change.
        BeforeCount := EntryCount('');
        // [WHEN] It is used for all applicable code fields.
        Response := DispatchImport(' XSPACE', ' XSPACE', 'X82.csv');
        // [THEN] Both independent code errors are collected, with original spelling.
        AssertRefusal(Response, 'InvalidParameterFormat', 'dataExchDefCode', ' XSPACE');
        AssertRefusal(Response, 'InvalidParameterFormat', 'storageCode', ' XSPACE');
        LibraryAssert.AreEqual(2, ErrorCount(Response), 'Both codes must refuse.');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Invalid codes must not write.');
        Response := DispatchDelete(' XSPACE');
        AssertRefusal(Response, 'InvalidParameterFormat', 'code', ' XSPACE');
    end;

    /// <summary>Noncanonical or overlong codes refuse before normalization.</summary>
    [Test]
    procedure Scenario_AC02_TrailingSpace_RefusesRawCode()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A raw key that Code20 conversion would change.
        BeforeCount := EntryCount('');
        // [WHEN] It is used for all applicable code fields.
        Response := DispatchImport('XSPACE ', 'XSPACE ', 'X82.csv');
        // [THEN] Both independent code errors are collected, with original spelling.
        AssertRefusal(Response, 'InvalidParameterFormat', 'dataExchDefCode', 'XSPACE ');
        AssertRefusal(Response, 'InvalidParameterFormat', 'storageCode', 'XSPACE ');
        LibraryAssert.AreEqual(2, ErrorCount(Response), 'Both codes must refuse.');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Invalid codes must not write.');
        Response := DispatchDelete('XSPACE ');
        AssertRefusal(Response, 'InvalidParameterFormat', 'code', 'XSPACE ');
    end;

    /// <summary>Noncanonical or overlong codes refuse before normalization.</summary>
    [Test]
    procedure Scenario_AC02_Overlong_RefusesRawCode()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A raw key that Code20 conversion would change.
        BeforeCount := EntryCount('');
        // [WHEN] It is used for all applicable code fields.
        Response := DispatchImport('X12345678901234567890', 'X12345678901234567890', 'X82.csv');
        // [THEN] Both independent code errors are collected, with original spelling.
        AssertRefusal(Response, 'InvalidParameterFormat', 'dataExchDefCode', 'X12345678901234567890');
        AssertRefusal(Response, 'InvalidParameterFormat', 'storageCode', 'X12345678901234567890');
        LibraryAssert.AreEqual(2, ErrorCount(Response), 'Both codes must refuse.');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Invalid codes must not write.');
        Response := DispatchDelete('X12345678901234567890');
        AssertRefusal(Response, 'InvalidParameterFormat', 'code', 'X12345678901234567890');
    end;

    /// <summary>Exact Code20 and path2048 limits preserve successful behavior.</summary>
    [Test]
    procedure Scenario_AC02_Code20AndPath2048_AcceptsExactBounds()
    var
        DataExchDef: Record "Data Exch. Def";
        Response: JsonObject;
        BoundaryCode: Code[20];
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A 20-character canonical definition.
        BoundaryCode := 'X1234567890123456789';
        DataExchDef.Code := BoundaryCode;
        DataExchDef.Type := DataExchDef.Type::"Generic Import";
        DataExchDef.Insert(true);
        // [WHEN] Both identifiers and the path are at their exact raw limits.
        Response := DispatchImport(BoundaryCode, BoundaryCode, PadStr('X', 2048, 'A'));
        // [THEN] The unchanged code is returned and one header was created.
        AssertText(Response, 'status', 'Accepted');
        AssertText(Response, 'dataExchDefCode', BoundaryCode);
        LibraryAssert.AreEqual(1, EntryCount(BoundaryCode), 'Boundary request must create its header.');
    end;

    /// <summary>An overlong path refuses without truncating it.</summary>
    [Test]
    procedure Scenario_AC02_Path2049_RefusesWithoutWrite()
    var
        DefinitionCode: Code[20];
        Response: JsonObject;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A valid definition and a path one character beyond the limit.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        // [WHEN] The input is dispatched.
        Response := DispatchImport(DefinitionCode, 'XSTORAGE', PadStr('X', 2049, 'A'));
        // [THEN] Foundation supplies bounded error detail and no header is created.
        AssertRefusal(Response, 'InvalidParameterFormat', 'path', '');
        LibraryAssert.AreEqual(0, EntryCount(DefinitionCode), 'An overlong path must not write.');
    end;

    /// <summary>Relative traversal is rejected in both slash forms.</summary>
    [Test]
    procedure Scenario_AC02_Traversal_RefusesWithoutWrite()
    var
        DefinitionCode: Code[20];
        Response: JsonObject;
        BadPath: Text;
        Paths: List of [Text];
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A valid definition and both traversal spellings.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        Paths.Add('X/../secret');
        Paths.Add('X\..\secret');
        Paths.Add('./X82.csv');
        // [WHEN] Each path reaches the registered handler.
        foreach BadPath in Paths do begin
            Response := DispatchImport(DefinitionCode, 'XSTORAGE', BadPath);
            // [THEN] The original path is refused and state stays unchanged.
            AssertRefusal(Response, 'InvalidParameter', 'path', BadPath);
            LibraryAssert.AreEqual(0, EntryCount(DefinitionCode), 'Traversal must not write.');
        end;
    end;

    /// <summary>Malformed and non-object JSON produces a complete data refusal.</summary>
    [Test]
    procedure Scenario_AC02_MalformedOrScalar_RefusesData()
    var
        Response: JsonObject;
        Payloads: List of [Text];
        Payload: Text;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] Malformed and scalar/array request payloads.
        BeforeCount := EntryCount('');
        Payloads.Add('{');
        Payloads.Add('[]');
        Payloads.Add('null');
        Payloads.Add('true');
        Payloads.Add('1');
        Payloads.Add('"X"');
        // [WHEN] Each payload is dispatched.
        foreach Payload in Payloads do begin
            Response := Dispatch("Message Type ori"::"DataExchange.Import.Run", Payload);
            // [THEN] The refusal identifies data and no row was inserted.
            AssertRefusal(Response, 'InvalidParameterFormat', 'data', '');
            LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Bad JSON must not write.');
        end;
    end;

    /// <summary>Missing and prohibited definitions return actionable codes.</summary>
    [Test]
    procedure Scenario_AC01_UnknownAndWrongKind_RefusesDefinition()
    var
        Response: JsonObject;
        DefinitionCode: Code[20];
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] One nonexistent definition and one export definition.
        BeforeCount := EntryCount('');
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Export");
        // [WHEN] Both are requested through the shipped import.
        Response := DispatchImport('X82-NOT-FOUND', 'XSTORAGE', 'X82.csv');
        // [THEN] Lookup and kind failures remain distinct and no entry is written.
        AssertRefusal(Response, 'RecordNotFound', 'dataExchDefCode', 'X82-NOT-FOUND');
        Response := DispatchImport(DefinitionCode, 'XSTORAGE', 'X82.csv');
        AssertRefusal(Response, 'InvalidParameter', 'dataExchDefCode', DefinitionCode);
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Invalid definitions must not write.');
    end;

    /// <summary>Successful definition deletion retains standard delete triggers.</summary>
    [Test]
    procedure Scenario_AC03_DeleteUnreferenced_DeletesChildren()
    var
        DataExchDef: Record "Data Exch. Def";
        LineDef: Record "Data Exch. Line Def";
        DefinitionCode: Code[20];
        Response: JsonObject;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] An unreferenced definition with one standard child.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        CreateLine(DefinitionCode);
        // [WHEN] The registered delete operation runs.
        Response := DispatchDelete(DefinitionCode);
        // [THEN] Success identifies the deleted key, and parent and child are absent.
        AssertText(Response, 'status', 'Success');
        AssertText(Response, 'code', DefinitionCode);
        LibraryAssert.IsFalse(DataExchDef.Get(DefinitionCode), 'Definition must be deleted.');
        LibraryAssert.IsFalse(LineDef.Get(DefinitionCode, 'XLINE'), 'Delete triggers must remove children.');
    end;

    /// <summary>Referenced definitions and children remain unchanged.</summary>
    [Test]
    procedure Scenario_AC01_DeleteTypeReferenced_PreservesTree()
    var
        DataExchDef: Record "Data Exch. Def";
        LineDef: Record "Data Exch. Line Def";
        DataExchangeType: Record "Data Exchange Type";
        DefinitionCode: Code[20];
        Response: JsonObject;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A definition, child and existing type reference.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        CreateLine(DefinitionCode);
        DataExchangeType.Code := DefinitionCode;
        DataExchangeType."Data Exch. Def. Code" := DefinitionCode;
        DataExchangeType.Insert(true);
        // [WHEN] Deletion is requested.
        Response := DispatchDelete(DefinitionCode);
        // [THEN] The reference refusal preserves all rows.
        AssertRefusal(Response, 'PreconditionFailed', 'code', DefinitionCode);
        LibraryAssert.IsTrue(DataExchDef.Get(DefinitionCode), 'Definition must survive refusal.');
        LibraryAssert.IsTrue(LineDef.Get(DefinitionCode, 'XLINE'), 'Child must survive refusal.');
        LibraryAssert.IsTrue(DataExchangeType.Get(DefinitionCode), 'Reference must survive refusal.');
        LibraryAssert.AreEqual(DefinitionCode, DataExchangeType."Data Exch. Def. Code", 'Reference must remain unchanged.');
    end;

    /// <summary>Referenced definitions and children remain unchanged.</summary>
    [Test]
    procedure Scenario_AC01_DeleteBankReferenced_PreservesTree()
    var
        DataExchDef: Record "Data Exch. Def";
        LineDef: Record "Data Exch. Line Def";
        BankSetup: Record "Bank Export/Import Setup";
        DefinitionCode: Code[20];
        Response: JsonObject;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A definition, child and existing bank reference.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        CreateLine(DefinitionCode);
        BankSetup.Code := DefinitionCode;
        BankSetup."Data Exch. Def. Code" := DefinitionCode;
        BankSetup.Insert(true);
        // [WHEN] Deletion is requested.
        Response := DispatchDelete(DefinitionCode);
        // [THEN] The reference refusal preserves all rows.
        AssertRefusal(Response, 'PreconditionFailed', 'code', DefinitionCode);
        LibraryAssert.IsTrue(DataExchDef.Get(DefinitionCode), 'Definition must survive refusal.');
        LibraryAssert.IsTrue(LineDef.Get(DefinitionCode, 'XLINE'), 'Child must survive refusal.');
        LibraryAssert.IsTrue(BankSetup.Get(DefinitionCode), 'Reference must survive refusal.');
        LibraryAssert.AreEqual(DefinitionCode, BankSetup."Data Exch. Def. Code", 'Reference must remain unchanged.');
    end;

    /// <summary>Deletion of an unknown definition reports RecordNotFound.</summary>
    [Test]
    procedure Scenario_AC01_DeleteMissing_ReportsCompleteError()
    var
        DataExchDef: Record "Data Exch. Def";
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] The current definition count.
        BeforeCount := DataExchDef.Count();
        // [WHEN] An unknown canonical key is deleted.
        Response := DispatchDelete('X82-NOT-FOUND');
        // [THEN] The complete error leaves the definitions unchanged.
        AssertRefusal(Response, 'RecordNotFound', 'code', 'X82-NOT-FOUND');
        LibraryAssert.AreEqual(BeforeCount, DataExchDef.Count(), 'Missing delete must not change data.');
    end;

    /// <summary>Real orchestration selects English and Icelandic error text.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC03_TwoLocales_CollectsLocalizedErrors()
    var
        EnglishResponse: JsonObject;
        IcelandicResponse: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] An empty request and the current entry count.
        BeforeCount := EntryCount('');
        // [WHEN] The real public queue path chooses each language.
        EnglishResponse := DispatchLocale('{}', 1033);
        IcelandicResponse := DispatchLocale('{}', 1039);
        // [THEN] Both envelopes are complete and errors actually differ by locale.
        AssertThreeInputErrors(EnglishResponse, 'MissingParameter');
        AssertThreeInputErrors(IcelandicResponse, 'MissingParameter');
        LibraryAssert.AreNotEqual(TextProperty(FindError(EnglishResponse, 'path'), 'error'), TextProperty(FindError(IcelandicResponse, 'path'), 'error'), 'Icelandic errors must be translated at runtime.');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Localized refusal must not write.');
    end;

    /// <summary>A real postwrite table event failure rolls back the affected tree.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC04_AfterInsertFailure_RollsBack()
    var
        DataExchDef: Record "Data Exch. Def";
        LineDef: Record "Data Exch. Line Def";
        Faults: Codeunit "DataExch Refusal82 Tests ori";
        DefinitionCode: Code[20];
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] Committed fixtures before the operation under test, and a targeted standard table-event failure.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        CreateLine(DefinitionCode);
        Commit();
        Faults.ConfigureFailure(DefinitionCode, true, false);
        BindSubscription(Faults);
        // [WHEN] The operation mutates and the standard event subscriber raises.
        asserterror DispatchImport(DefinitionCode, 'XSTORAGE', 'X82.csv');
        LibraryAssert.ExpectedError('X82 postwrite failure');
        UnbindSubscription(Faults);
        // [THEN] The mutation rolled back, including trigger-deleted children.
        LibraryAssert.AreEqual(0, EntryCount(DefinitionCode), 'The failed insert must not persist.');
        LibraryAssert.IsTrue(DataExchDef.Get(DefinitionCode), 'Definition must survive failed execution.');
        LibraryAssert.IsTrue(LineDef.Get(DefinitionCode, 'XLINE'), 'Child must survive failed execution.');
        DataExchDef.Delete(true);
        Commit();
    end;

    /// <summary>A real postwrite table event failure rolls back the affected tree.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC04_AfterDeleteFailure_RollsBack()
    var
        DataExchDef: Record "Data Exch. Def";
        LineDef: Record "Data Exch. Line Def";
        Faults: Codeunit "DataExch Refusal82 Tests ori";
        DefinitionCode: Code[20];
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] Committed fixtures before the operation under test, and a targeted standard table-event failure.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        CreateLine(DefinitionCode);
        Commit();
        Faults.ConfigureFailure(DefinitionCode, false, true);
        BindSubscription(Faults);
        // [WHEN] The operation mutates and the standard event subscriber raises.
        asserterror DispatchDelete(DefinitionCode);
        LibraryAssert.ExpectedError('X82 postwrite failure');
        UnbindSubscription(Faults);
        // [THEN] The mutation rolled back, including trigger-deleted children.
        LibraryAssert.AreEqual(0, EntryCount(DefinitionCode), 'The failed insert must not persist.');
        LibraryAssert.IsTrue(DataExchDef.Get(DefinitionCode), 'Definition must survive failed execution.');
        LibraryAssert.IsTrue(LineDef.Get(DefinitionCode, 'XLINE'), 'Child must survive failed execution.');
        DataExchDef.Delete(true);
        Commit();
    end;

    /// <summary>A later failure rolls back a prior successful OmitCommit call.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC04_ChainedFailure_RollsBackEarlierImport()
    var
        DataExchDef: Record "Data Exch. Def";
        Faults: Codeunit "DataExch Refusal82 Tests ori";
        DefinitionCode: Code[20];
    begin
        // Story #82 | Time: independent of Today and WorkDate | Risk: requires canonical PR84 and real Foundation dispatch.
        // [GIVEN] A committed definition and a failure only on the later delete.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        Commit();
        Faults.ConfigureFailure(DefinitionCode, false, true);
        BindSubscription(Faults);
        // [WHEN] Two real default OmitCommit dispatches execute in one caller chain.
        asserterror ImportThenDelete(DefinitionCode);
        LibraryAssert.ExpectedError('X82 postwrite failure');
        UnbindSubscription(Faults);
        // [THEN] The earlier Accepted import was not implicitly committed.
        LibraryAssert.AreEqual(0, EntryCount(DefinitionCode), 'An earlier chained write must roll back.');
        LibraryAssert.IsTrue(DataExchDef.Get(DefinitionCode), 'The failed delete must roll back.');
        DataExchDef.Delete(true);
        Commit();
    end;

    /// <summary>A canonical Unicode key is accepted without ASCII-only restrictions.</summary>
    [Test]
    procedure Scenario_AC02_CanonicalUnicode_AcceptsUnchangedKey()
    var
        DataExchDef: Record "Data Exch. Def";
        Response: JsonObject;
    begin
        // Story #82, AC02 | Time: none | Risk: Unicode BC Code rules.
        // [GIVEN] An already canonical Unicode definition.
        DataExchDef.Code := 'XÞÓR';
        DataExchDef.Type := DataExchDef.Type::"Generic Import";
        DataExchDef.Insert(true);
        // [WHEN] The unchanged key reaches the registered handler.
        Response := DispatchImport('XÞÓR', 'XSTORAGE', 'X82.csv');
        // [THEN] It succeeds and persists the same key.
        AssertText(Response, 'status', 'Accepted');
        AssertText(Response, 'dataExchDefCode', 'XÞÓR');
        LibraryAssert.AreEqual(1, EntryCount('XÞÓR'), 'Canonical Unicode must be accepted.');
    end;

    /// <summary>Whitespace-only input is invalid format and still has complete received detail.</summary>
    [Test]
    procedure Scenario_AC02_SpacesOnly_ReportsCompleteCodeError()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82, AC02 | Time: none | Risk: collector omits empty received text.
        // [GIVEN] A key that BC Code normalization would erase.
        BeforeCount := EntryCount('');
        // [WHEN] Both independent code fields are supplied as spaces.
        Response := DispatchImport('   ', '   ', 'X82.csv');
        // [THEN] JSON-serialized whitespace keeps the original received value visible.
        AssertRefusal(Response, 'InvalidParameterFormat', 'dataExchDefCode', '"   "');
        AssertRefusal(Response, 'InvalidParameterFormat', 'storageCode', '"   "');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Whitespace must not write.');
    end;

    /// <summary>Export retains its shipped header-only behavior and exact file name.</summary>
    [Test]
    procedure Scenario_AC03_Export_CreatesOnlyNamedHeader()
    var
        DataExch: Record "Data Exch.";
        DefinitionCode: Code[20];
        Response: JsonObject;
    begin
        // Story #82, AC03 | Time: none | Risk: real Foundation dispatch.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Export");
        Response := DispatchExport(DefinitionCode, 'X82.csv');
        AssertText(Response, 'status', 'Success');
        DataExch.Get(IntegerProperty(Response, 'entryNo'));
        LibraryAssert.AreEqual(DefinitionCode, DataExch."Data Exch. Def Code", 'Header definition mismatch.');
        LibraryAssert.AreEqual('X82.csv', DataExch."File Name", 'Header file name mismatch.');
        DataExch.CalcFields("File Content");
        LibraryAssert.IsFalse(DataExch."File Content".HasValue(), 'Export must remain header-only.');
        LibraryAssert.AreEqual(1, EntryCount(DefinitionCode), 'Export must create exactly one header.');
    end;

    /// <summary>The shipped export predicate continues accepting Payroll Import.</summary>
    [Test]
    procedure Scenario_AC03_ExportPayroll_PreservesShippedPredicate()
    var
        DefinitionCode: Code[20];
        Response: JsonObject;
    begin
        // Story #82, AC03 | Time: none | Risk: predicate compatibility.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Payroll Import");
        Response := DispatchExport(DefinitionCode, 'X82.csv');
        AssertText(Response, 'status', 'Success');
        LibraryAssert.AreEqual(1, EntryCount(DefinitionCode), 'Payroll predicate must remain unchanged.');
    end;

    /// <summary>Export collects both invalid raw inputs before writing.</summary>
    [Test]
    procedure Scenario_AC02_ExportWrongTypes_CollectsWithoutWrite()
    var
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82, AC02 | Time: none | Risk: no side effects on refusal.
        BeforeCount := EntryCount('');
        Response := Dispatch("Message Type ori"::"DataExchange.Export.Run", '{"dataExchDefCode":[],"fileName":false}');
        AssertRefusal(Response, 'InvalidParameterFormat', 'dataExchDefCode', '');
        AssertRefusal(Response, 'InvalidParameterFormat', 'fileName', '');
        LibraryAssert.AreEqual(2, ErrorCount(Response), 'Both errors must be collected.');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Refused export must not write.');
    end;

    /// <summary>Export rejects missing and wrong-kind definitions before creating a header.</summary>
    [Test]
    procedure Scenario_AC01_ExportMissingOrWrongKind_DoesNotWrite()
    var
        DefinitionCode: Code[20];
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82, AC01 | Time: none | Risk: no side effects on refusal.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        BeforeCount := EntryCount('');
        Response := DispatchExport(DefinitionCode, 'X82.csv');
        AssertRefusal(Response, 'InvalidParameter', 'dataExchDefCode', DefinitionCode);
        Response := DispatchExport('X82MISSING', 'X82.csv');
        AssertRefusal(Response, 'RecordNotFound', 'dataExchDefCode', 'X82MISSING');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(''), 'Refused definitions must not create headers.');
    end;

    /// <summary>File-name boundary is accepted exactly; one character beyond is refused.</summary>
    [Test]
    procedure Scenario_AC02_ExportFileNameBounds_NeverTruncates()
    var
        DataExch: Record "Data Exch.";
        DefinitionCode: Code[20];
        FileName: Text;
        Response: JsonObject;
    begin
        // Story #82, AC02 | Time: none | Risk: storage field length.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Export");
        FileName := PadStr('', MaxStrLen(DataExch."File Name"), 'X');
        Response := DispatchExport(DefinitionCode, FileName);
        AssertText(Response, 'status', 'Success');
        DataExch.Get(IntegerProperty(Response, 'entryNo'));
        LibraryAssert.AreEqual(FileName, DataExch."File Name", 'Exact limit must remain unchanged.');
        Response := DispatchExport(DefinitionCode, FileName + 'X');
        AssertRefusal(Response, 'InvalidParameterFormat', 'fileName', '');
        LibraryAssert.AreEqual(1, EntryCount(DefinitionCode), 'Overlong input must not create another header.');
    end;

    /// <summary>Type creation and update persist the requested binding and optional description semantics.</summary>
    [Test]
    procedure Scenario_AC03_TypeSet_CreateUpdatePreservesOmittedDescription()
    var
        DataExchangeType: Record "Data Exchange Type";
        DefinitionCode: Code[20];
        OtherDefinitionCode: Code[20];
        Response: JsonObject;
    begin
        // Story #82, AC03 | Time: none | Risk: standard Validate still runs.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        OtherDefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        Response := DispatchTypeSet(DefinitionCode, DefinitionCode, true, 'X82 original');
        AssertText(Response, 'status', 'Success');
        DataExchangeType.Get(DefinitionCode);
        LibraryAssert.AreEqual('X82 original', DataExchangeType.Description, 'Description must persist.');
        Response := DispatchTypeSet(DefinitionCode, OtherDefinitionCode, false, '');
        AssertText(Response, 'status', 'Success');
        DataExchangeType.Get(DefinitionCode);
        LibraryAssert.AreEqual(OtherDefinitionCode, DataExchangeType."Data Exch. Def. Code", 'Updated binding must persist.');
        LibraryAssert.AreEqual('X82 original', DataExchangeType.Description, 'Omitted description must be preserved.');
        Response := DispatchTypeSet(DefinitionCode, OtherDefinitionCode, true, '');
        AssertText(Response, 'status', 'Success');
        DataExchangeType.Get(DefinitionCode);
        LibraryAssert.AreEqual('', DataExchangeType.Description, 'Explicit empty description must clear the value.');
    end;

    /// <summary>Malformed type inputs cannot replace the persisted binding or description.</summary>
    [Test]
    procedure Scenario_AC02_TypeSetOverlongDescription_PreservesExisting()
    var
        DataExchangeType: Record "Data Exchange Type";
        DefinitionCode: Code[20];
        OtherDefinitionCode: Code[20];
        Response: JsonObject;
    begin
        // Story #82, AC02 | Time: none | Risk: no silent truncation or partial writes.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        OtherDefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        Response := DispatchTypeSet(DefinitionCode, DefinitionCode, true, 'X82 original');
        AssertText(Response, 'status', 'Success');
        Response := DispatchTypeSet(DefinitionCode, OtherDefinitionCode, true, PadStr('', MaxStrLen(DataExchangeType.Description) + 1, 'X'));
        AssertRefusal(Response, 'InvalidParameterFormat', 'description', '');
        DataExchangeType.Get(DefinitionCode);
        LibraryAssert.AreEqual(DefinitionCode, DataExchangeType."Data Exch. Def. Code", 'Refusal must preserve original binding.');
        LibraryAssert.AreEqual('X82 original', DataExchangeType.Description, 'Refusal must preserve original description.');
    end;

    /// <summary>Both code fields and description report their independent invalid types.</summary>
    [Test]
    procedure Scenario_AC02_TypeSetWrongTypes_CollectsWithoutWrite()
    var
        DataExchangeType: Record "Data Exchange Type";
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #82, AC02 | Time: none | Risk: complete error collection before write.
        BeforeCount := DataExchangeType.Count();
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Set", '{"code":[],"dataExchDefCode":false,"description":{}}');
        AssertRefusal(Response, 'InvalidParameterFormat', 'code', '');
        AssertRefusal(Response, 'InvalidParameterFormat', 'dataExchDefCode', '');
        AssertRefusal(Response, 'InvalidParameterFormat', 'description', '');
        LibraryAssert.AreEqual(3, ErrorCount(Response), 'All errors must be collected.');
        LibraryAssert.AreEqual(BeforeCount, DataExchangeType.Count(), 'Refusal must not create a type.');
    end;

    /// <summary>Payroll definitions remain refused by Type.Set without creating a row.</summary>
    [Test]
    procedure Scenario_AC01_TypeSetPayroll_DoesNotCreateType()
    var
        DataExchangeType: Record "Data Exchange Type";
        DefinitionCode: Code[20];
        Response: JsonObject;
    begin
        // Story #82, AC01 | Time: none | Risk: shipped predicate compatibility.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Payroll Import");
        Response := DispatchTypeSet(DefinitionCode, DefinitionCode, false, '');
        AssertRefusal(Response, 'InvalidParameter', 'dataExchDefCode', DefinitionCode);
        LibraryAssert.IsFalse(DataExchangeType.Get(DefinitionCode), 'Wrong-kind refusal must not create a row.');
    end;

    /// <summary>Export's post-insert failure cannot leave a new header.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC04_ExportAfterInsertFailure_RollsBack()
    var
        DataExchDef: Record "Data Exch. Def";
        Faults: Codeunit "DataExch Refusal82 Tests ori";
        DefinitionCode: Code[20];
    begin
        // Story #82, AC04 | Time: none | Risk: real postwrite table trigger, committed fixture.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Export");
        Commit();
        Faults.ConfigureFailure(DefinitionCode, true, false);
        BindSubscription(Faults);
        asserterror DispatchExport(DefinitionCode, 'X82.csv');
        LibraryAssert.ExpectedError('X82 postwrite failure');
        UnbindSubscription(Faults);
        LibraryAssert.AreEqual(0, EntryCount(DefinitionCode), 'Failed export must roll back header.');
        DataExchDef.Get(DefinitionCode);
        DataExchDef.Delete(true);
        Commit();
    end;

    /// <summary>Type.Set's post-modify failure rolls back its inserted row.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC04_TypeSetAfterModifyFailure_RollsBackInsert()
    var
        DataExchangeType: Record "Data Exchange Type";
        DataExchDef: Record "Data Exch. Def";
        Faults: Codeunit "DataExch Refusal82 Tests ori";
        DefinitionCode: Code[20];
    begin
        // Story #82, AC04 | Time: none | Risk: both insert and modify in same transaction.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        Commit();
        Faults.ConfigureTypeFailure(DefinitionCode);
        BindSubscription(Faults);
        asserterror DispatchTypeSet(DefinitionCode, DefinitionCode, true, 'X82 failure');
        LibraryAssert.ExpectedError('X82 type postwrite failure');
        UnbindSubscription(Faults);
        LibraryAssert.IsFalse(DataExchangeType.Get(DefinitionCode), 'Failed modify must also roll back prior insert.');
        DataExchDef.Get(DefinitionCode);
        DataExchDef.Delete(true);
        Commit();
    end;

    /// <summary>A failed update restores the previous binding and description.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC04_TypeSetAfterModifyFailure_RestoresOriginal()
    var
        DataExchangeType: Record "Data Exchange Type";
        DataExchDef: Record "Data Exch. Def";
        Faults: Codeunit "DataExch Refusal82 Tests ori";
        DefinitionCode: Code[20];
        OtherDefinitionCode: Code[20];
        Response: JsonObject;
    begin
        // Story #82, AC04 | Time: none | Risk: real postwrite rollback with committed baseline.
        DefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        OtherDefinitionCode := CreateDefinition(Enum::"Data Exchange Definition Type"::"Generic Import");
        Response := DispatchTypeSet(DefinitionCode, DefinitionCode, true, 'X82 original');
        AssertText(Response, 'status', 'Success');
        Commit();
        Faults.ConfigureTypeFailure(OtherDefinitionCode);
        BindSubscription(Faults);
        asserterror DispatchTypeSet(DefinitionCode, OtherDefinitionCode, true, 'X82 replacement');
        LibraryAssert.ExpectedError('X82 type postwrite failure');
        UnbindSubscription(Faults);
        DataExchangeType.Get(DefinitionCode);
        LibraryAssert.AreEqual(DefinitionCode, DataExchangeType."Data Exch. Def. Code", 'Failed update must restore binding.');
        LibraryAssert.AreEqual('X82 original', DataExchangeType.Description, 'Failed update must restore description.');
        DataExchangeType.Delete(true);
        DataExchDef.Get(DefinitionCode);
        DataExchDef.Delete(true);
        DataExchDef.Get(OtherDefinitionCode);
        DataExchDef.Delete(true);
        Commit();
    end;

    /// <summary>Arms only the named fixture's type-modification failure.</summary>
    /// <param name="DefinitionCode">The definition bound by the fixture.</param>
    internal procedure ConfigureTypeFailure(DefinitionCode: Code[20])
    begin
        FailureDefinitionCode := DefinitionCode;
        FailTypeModify := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Data Exchange Type", 'OnAfterModifyEvent', '', false, false)]
    local procedure FailAfterTypeModify(var Rec: Record "Data Exchange Type"; var xRec: Record "Data Exchange Type"; RunTrigger: Boolean)
    var
        FailureErr: Label 'X82 type postwrite failure', Locked = true;
    begin
        if FailTypeModify and not Rec.IsTemporary() and RunTrigger and (Rec."Data Exch. Def. Code" = FailureDefinitionCode) then
            Error(FailureErr);
    end;

    local procedure DispatchExport(DefinitionCode: Text; FileName: Text): JsonObject
    var
        Request: JsonObject;
        Payload: Text;
    begin
        Request.Add('dataExchDefCode', DefinitionCode);
        Request.Add('fileName', FileName);
        Request.WriteTo(Payload);
        exit(Dispatch("Message Type ori"::"DataExchange.Export.Run", Payload));
    end;

    local procedure DispatchTypeSet(TypeCode: Text; DefinitionCode: Text; IncludeDescription: Boolean; Description: Text): JsonObject
    var
        Request: JsonObject;
        Payload: Text;
    begin
        Request.Add('code', TypeCode);
        Request.Add('dataExchDefCode', DefinitionCode);
        if IncludeDescription then
            Request.Add('description', Description);
        Request.WriteTo(Payload);
        exit(Dispatch("Message Type ori"::"DataExchange.Type.Set", Payload));
    end;

    /// <summary>Arms only this manually bound test subscriber instance for a specific fixture.</summary>
    /// <param name="DefinitionCode">The exact fixture key.</param>
    /// <param name="OnInsert">Whether to fail after an entry insert.</param>
    /// <param name="OnDelete">Whether to fail after a definition delete.</param>
    internal procedure ConfigureFailure(DefinitionCode: Code[20]; OnInsert: Boolean; OnDelete: Boolean)
    begin
        FailureDefinitionCode := DefinitionCode;
        FailInsert := OnInsert;
        FailDelete := OnDelete;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Data Exch.", 'OnAfterInsertEvent', '', false, false)]
    local procedure FailAfterEntryInsert(var Rec: Record "Data Exch."; RunTrigger: Boolean)
    var
        FailureErr: Label 'X82 postwrite failure', Locked = true;
    begin
        if FailInsert and not Rec.IsTemporary() and RunTrigger and (Rec."Data Exch. Def Code" = FailureDefinitionCode) then
            Error(FailureErr);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Data Exch. Def", 'OnAfterDeleteEvent', '', false, false)]
    local procedure FailAfterDefinitionDelete(var Rec: Record "Data Exch. Def"; RunTrigger: Boolean)
    var
        FailureErr: Label 'X82 postwrite failure', Locked = true;
    begin
        if FailDelete and not Rec.IsTemporary() and RunTrigger and (Rec.Code = FailureDefinitionCode) then
            Error(FailureErr);
    end;

    local procedure ImportThenDelete(DefinitionCode: Code[20])
    var
        Response: JsonObject;
    begin
        Response := DispatchImport(DefinitionCode, 'XSTORAGE', 'X82.csv');
        AssertText(Response, 'status', 'Accepted');
        LibraryAssert.AreEqual(1, EntryCount(DefinitionCode), 'First call must actually write before the later failure.');
        DispatchDelete(DefinitionCode);
    end;

    local procedure CreateDefinition(DefinitionType: Enum "Data Exchange Definition Type"): Code[20]
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        DataExchDef.Code := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(DataExchDef.Code));
        DataExchDef.Type := DefinitionType;
        DataExchDef.Insert(true);
        exit(DataExchDef.Code);
    end;

    local procedure CreateLine(DefinitionCode: Code[20])
    var
        LineDef: Record "Data Exch. Line Def";
    begin
        LineDef."Data Exch. Def Code" := DefinitionCode;
        LineDef.Code := 'XLINE';
        LineDef.Name := 'X82 child';
        LineDef.Insert(true);
    end;

    local procedure DispatchImport(DefinitionCode: Text; StorageCode: Text; Path: Text): JsonObject
    var
        Request: JsonObject;
        Payload: Text;
    begin
        Request.Add('dataExchDefCode', DefinitionCode);
        Request.Add('storageCode', StorageCode);
        Request.Add('path', Path);
        Request.WriteTo(Payload);
        exit(Dispatch("Message Type ori"::"DataExchange.Import.Run", Payload));
    end;

    local procedure DispatchDelete(DefinitionCode: Text): JsonObject
    var
        Request: JsonObject;
        Payload: Text;
    begin
        Request.Add('code', DefinitionCode);
        Request.WriteTo(Payload);
        exit(Dispatch("Message Type ori"::"DataExchange.Definition.Delete", Payload));
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Payload: Text) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseType: Text[100];
        ResponseText: Text;
    begin
        RequestContent.AddText(Payload);
        Dispatcher.Execute(MessageType, "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, ResponseContent, ResponseType);
        ResponseContent.GetSubText(ResponseText, 1);
        LibraryAssert.IsTrue(Response.ReadFrom(ResponseText), 'A real dispatch must return a JSON response.');
    end;

    local procedure DispatchLocale(Payload: Text; LanguageId: Integer) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        TaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseType: Text[100];
        ResponseText: Text;
    begin
        RequestContent.AddText(Payload);
        Dispatcher.EnqueueAndProcess("Message Type ori"::"DataExchange.Import.Run", "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, TaskId, LanguageId, MessageId, ResponseContent, ResponseType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        LibraryAssert.IsTrue(Response.ReadFrom(ResponseText), 'The public queue path must return JSON.');
    end;

    local procedure EntryCount(DefinitionCode: Code[20]): Integer
    var
        DataExch: Record "Data Exch.";
    begin
        DataExch.ReadIsolation := IsolationLevel::ReadCommitted;
        if DefinitionCode <> '' then
            DataExch.SetRange("Data Exch. Def Code", DefinitionCode);
        exit(DataExch.Count());
    end;

    local procedure AssertThreeInputErrors(Response: JsonObject; ExpectedCode: Text)
    begin
        AssertText(Response, 'status', 'Error');
        AssertText(Response, 'code', 'MultipleErrors');
        LibraryAssert.AreEqual(3, ErrorCount(Response), 'Exactly three input errors are required.');
        AssertRefusal(Response, ExpectedCode, 'dataExchDefCode', '');
        AssertRefusal(Response, ExpectedCode, 'storageCode', '');
        AssertRefusal(Response, ExpectedCode, 'path', '');
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text; ParameterName: Text; ExpectedReceived: Text)
    var
        Detail: JsonObject;
    begin
        AssertText(Response, 'status', 'Error');
        Detail := FindError(Response, ParameterName);
        AssertText(Detail, 'code', ExpectedCode);
        AssertText(Detail, 'parameter', ParameterName);
        LibraryAssert.AreNotEqual('', TextProperty(Detail, 'error'), 'The refusal message must be present.');
        LibraryAssert.AreNotEqual('', TextProperty(Detail, 'received'), 'Received must not be omitted.');
        LibraryAssert.AreNotEqual('', TextProperty(Detail, 'expected'), 'Expected must be actionable.');
        LibraryAssert.AreNotEqual('', TextProperty(Detail, 'nextStep'), 'Recovery instructions must be present.');
        if ExpectedReceived <> '' then
            AssertText(Detail, 'received', ExpectedReceived);
    end;

    local procedure FindError(Response: JsonObject; ParameterName: Text) Detail: JsonObject
    var
        ErrorsToken: JsonToken;
        ErrorToken: JsonToken;
    begin
        if not Response.Get('errors', ErrorsToken) then begin
            AssertText(Response, 'parameter', ParameterName);
            exit(Response);
        end;
        foreach ErrorToken in ErrorsToken.AsArray() do begin
            Detail := ErrorToken.AsObject();
            if TextProperty(Detail, 'parameter') = ParameterName then
                exit(Detail);
        end;
        LibraryAssert.Fail('The requested parameter error was not collected: ' + ParameterName);
    end;

    local procedure ErrorCount(Response: JsonObject): Integer
    var
        ErrorsToken: JsonToken;
    begin
        if Response.Get('errors', ErrorsToken) then
            exit(ErrorsToken.AsArray().Count());
        exit(1);
    end;

    local procedure AssertText(Response: JsonObject; PropertyName: Text; ExpectedText: Text)
    begin
        LibraryAssert.AreEqual(ExpectedText, TextProperty(Response, PropertyName), 'Unexpected value for ' + PropertyName);
    end;

    local procedure TextProperty(Response: JsonObject; PropertyName: Text): Text
    var
        PropertyToken: JsonToken;
    begin
        LibraryAssert.IsTrue(Response.Get(PropertyName, PropertyToken), 'Missing property ' + PropertyName);
        exit(PropertyToken.AsValue().AsText());
    end;

    local procedure IntegerProperty(Response: JsonObject; PropertyName: Text): Integer
    var
        PropertyToken: JsonToken;
    begin
        LibraryAssert.IsTrue(Response.Get(PropertyName, PropertyToken), 'Missing property ' + PropertyName);
        exit(PropertyToken.AsValue().AsInteger());
    end;
}
