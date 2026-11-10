namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue 211: DataExchange.Definition.Delete is disabled. It reports IsEnabled false, every call is refused with a
/// typed error in 1033 and 1039, no definition is deleted, and the contract says so.
/// </summary>
codeunit 96281 "DataExch Def Del211 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "DataExch Fixture ori";
        LibraryAssert: Codeunit "Library Assert";

    /// <summary>AC1: the implementation reports that the message type is disabled.</summary>
    [Test]
    procedure Scenario_AC01_IsEnabled_IsFalse()
    var
        Implementation: Codeunit "DataExch Def Delete Impl ori";
        MsgInterface: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
    begin
        // [GIVEN] The registered Definition.Delete message type.
        MessageType := MessageType::"DataExchange.Definition.Delete";
        // [WHEN] The enum resolves to its implementation.
        MsgInterface := MessageType;
        // [THEN] Both the direct implementation and the enum binding report disabled.
        LibraryAssert.IsFalse(Implementation.IsEnabled(), 'The implementation must be disabled.');
        LibraryAssert.IsFalse(MsgInterface.IsEnabled(), 'The registered message type must be disabled.');
    end;

    /// <summary>AC2: a call in 1033 returns the typed error and deletes nothing.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC02_Execute_RefusedAndKeepsDefinition_1033()
    begin
        CheckRefusedAndKept(1033);
    end;

    /// <summary>AC2: a call in 1039 returns the typed error and deletes nothing.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC02_Execute_RefusedAndKeepsDefinition_1039()
    begin
        CheckRefusedAndKept(1039);
    end;

    /// <summary>AC3: the contract reports the disabled state and documents the error.</summary>
    [Test]
    procedure Scenario_AC03_Contract_ReportsDisabledState()
    var
        Implementation: Codeunit "DataExch Def Delete Impl ori";
        Contract: Interface "Msg Contract ori";
        Errors: JsonArray;
        Examples: JsonArray;
        Parameters: JsonArray;
        ErrorToken: JsonToken;
        ExampleToken: JsonToken;
        ExampleResponseToken: JsonToken;
        ParameterToken: JsonToken;
        Overview: Text;
        Notes: Text;
        SavedLanguageId: Integer;
    begin
        // Story #211, AC03 | Time: independent of Today()/WorkDate() | Risk: shared parameter defaults
        // [GIVEN] The contract chapters read in English.
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(1033);
        Contract := Implementation;
        // [WHEN] The chapters are built.
        Contract.GetErrors(Errors);
        Contract.GetExamples(Examples);
        Contract.GetParameters(Parameters);
        Contract.GetOverview(Overview);
        Contract.GetNotes(Notes);
        GlobalLanguage(SavedLanguageId);
        // [THEN] The overview and notes say disabled, only the ignored code is declared and the one error is PreconditionFailed.
        LibraryAssert.IsTrue(Overview.StartsWith('Disabled.'), 'The overview states the disabled state.');
        LibraryAssert.IsTrue(Notes.Contains('Disabled'), 'The notes state the disabled state.');
        LibraryAssert.AreEqual(1, Parameters.Count(), 'Only the ignored code is declared.');
        Parameters.Get(0, ParameterToken);
        LibraryAssert.AreEqual('code', Fixture.ReadText(ParameterToken.AsObject(), 'name'), 'The disabled operation must not require a storage connection.');
        LibraryAssert.AreEqual(1, Errors.Count(), 'The disabled error is the only documented error.');
        Errors.Get(0, ErrorToken);
        LibraryAssert.AreEqual('PreconditionFailed', Fixture.ReadText(ErrorToken.AsObject(), 'code'), 'The documented error code.');
        LibraryAssert.IsTrue(Fixture.ReadText(ErrorToken.AsObject(), 'fix').Contains('Business Central'), 'The next step names Business Central.');
        LibraryAssert.AreEqual(1, Examples.Count(), 'Only the disabled refusal example is documented.');
        Examples.Get(0, ExampleToken);
        ExampleToken.AsObject().Get('response', ExampleResponseToken);
        LibraryAssert.AreEqual('code', Fixture.ReadText(ExampleResponseToken.AsObject(), 'parameter'), 'The example refusal identifies the supplied code.');
        LibraryAssert.AreEqual('INVOICES', Fixture.ReadText(ExampleResponseToken.AsObject(), 'received'), 'The example refusal echoes the supplied code.');
    end;

    /// <summary>AC3: the discovery text says the type is disabled in both languages.</summary>
    [Test]
    procedure Scenario_AC03_Discovery_SaysDisabled_BothLanguages()
    var
        Implementation: Codeunit "DataExch Def Delete Impl ori";
        MsgInterface: Interface "Msg Interface ori";
        SavedLanguageId: Integer;
        English: Text;
        Icelandic: Text;
    begin
        // [GIVEN] The implementation behind the message type.
        MsgInterface := Implementation;
        SavedLanguageId := GlobalLanguage();
        // [WHEN] The description is read in 1033 and 1039.
        GlobalLanguage(1033);
        English := MsgInterface.GetDescription();
        GlobalLanguage(1039);
        Icelandic := MsgInterface.GetDescription();
        GlobalLanguage(SavedLanguageId);
        // [THEN] Both say disabled and name Business Central as the place to delete definitions.
        LibraryAssert.IsTrue(English.StartsWith('Disabled'), 'English description: ' + English);
        LibraryAssert.IsTrue(Icelandic.StartsWith('Óvirkt'), 'Icelandic description: ' + Icelandic);
        LibraryAssert.IsTrue(English.Contains('Business Central') and Icelandic.Contains('Business Central'), 'Both name Business Central.');
    end;

    local procedure CheckRefusedAndKept(LanguageId: Integer)
    var
        Definition: Record "Data Exch. Def";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        // [GIVEN] An existing unreferenced definition.
        DefCode := Fixture.CreateImportDefinition(0);
        Request.Add('code', DefCode);
        // [WHEN] Deletion is requested through the public dispatcher in the given language.
        Response := Dispatch(Request, LanguageId);
        // [THEN] The call is refused with the typed disabled error and the definition still exists.
        Fixture.AssertRefusal(Response, 'PreconditionFailed', 'code');
        LibraryAssert.AreEqual(DefCode, Fixture.ReadText(Response, 'received'), 'The refusal echoes the code that was sent.');
        if LanguageId = 1039 then
            LibraryAssert.AreEqual('DataExchange.Definition.Delete er óvirkt. Eyddu skilgreiningum gagnaskipta í Business Central.', Fixture.ReadText(Response, 'error'), 'Icelandic refusal text.')
        else
            LibraryAssert.AreEqual('DataExchange.Definition.Delete is disabled. Delete Data Exchange Definitions in Business Central.', Fixture.ReadText(Response, 'error'), 'English refusal text.');
        LibraryAssert.AreNotEqual('', Fixture.ReadText(Response, 'nextStep'), 'The refusal names a next step.');
        LibraryAssert.IsTrue(Definition.Get(DefCode), 'The definition must not be deleted.');
        Definition.Delete(true);
    end;

    local procedure Dispatch(Request: JsonObject; LanguageId: Integer) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        TestConfirmation: Codeunit "Storage Test Confirmation ori";
    begin
        Response := TestConfirmation.Dispatch(Dispatcher, "Message Type ori"::"DataExchange.Definition.Delete", Request, LanguageId, false);
    end;
}
