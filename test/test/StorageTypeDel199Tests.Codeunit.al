namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.TestLibraries.Utilities;

/// <summary>Issue 199: DataExchange.Type.Delete through the public dispatcher with explicit caller LCIDs.</summary>
codeunit 96277 "Storage TypeDel199 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "DataExch Fixture ori";
        LibraryAssert: Codeunit "Library Assert";

    /// <summary>AC1: counted confirmation, 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_CountedConfirmation_1033()
    begin
        CheckCountedConfirmation(1033);
    end;

    /// <summary>AC1: counted confirmation, 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_CountedConfirmation_1039()
    begin
        CheckCountedConfirmation(1039);
    end;

    /// <summary>AC2: a type used by an incoming document is refused, 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC02_TypeInUse_1033()
    begin
        CheckTypeInUse(1033);
    end;

    /// <summary>AC2: a type used by an incoming document is refused, 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC02_TypeInUse_1039()
    begin
        CheckTypeInUse(1039);
    end;

    /// <summary>AC3: the definition survives the type delete and then deletes, 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC03_DefinitionKept_1033()
    begin
        CheckDefinitionKept(1033);
    end;

    /// <summary>AC3: the definition survives the type delete and then deletes, 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC03_DefinitionKept_1039()
    begin
        CheckDefinitionKept(1039);
    end;

    /// <summary>Missing type and missing code are refused, 1033 and 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_MissingTypeAndCode()
    begin
        CheckMissing(1033);
        CheckMissing(1039);
    end;

    local procedure CheckCountedConfirmation(LanguageId: Integer)
    var
        ExchangeType: Record "Data Exchange Type";
        Definition: Record "Data Exch. Def";
        Request: JsonObject;
        Response: JsonObject;
        TypeCode: Code[20];
        DefCode: Code[20];
    begin
        // [GIVEN] A type bound to an owned definition.
        CreateType(TypeCode, DefCode);
        Request.Add('code', TypeCode);
        // [WHEN] No expectedCount is sent.
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Delete", Request, LanguageId);
        // [THEN] The call is only previewed and nothing is deleted.
        AssertRefusal(Response, 'ConfirmationRequired');
        LibraryAssert.IsTrue(ExchangeType.Get(TypeCode), 'Preview keeps the type.');
        // [WHEN] A wrong count is sent.
        Request.Add('expectedCount', 2);
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Delete", Request, LanguageId);
        AssertRefusal(Response, 'ConfirmationMismatch');
        LibraryAssert.IsTrue(ExchangeType.Get(TypeCode), 'Mismatch keeps the type.');
        // [WHEN] The right count is sent.
        Request.Replace('expectedCount', 1);
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Delete", Request, LanguageId);
        // [THEN] The type is deleted and the response names it.
        AssertSuccess(Response);
        LibraryAssert.AreEqual(TypeCode, Fixture.ReadText(Fixture.Data(Response), 'code'), 'Deleted code returned.');
        LibraryAssert.IsFalse(ExchangeType.Get(TypeCode), 'Type deleted.');
        Definition.Get(DefCode);
        Definition.Delete(true);
    end;

    local procedure CheckTypeInUse(LanguageId: Integer)
    var
        ExchangeType: Record "Data Exchange Type";
        Definition: Record "Data Exch. Def";
        IncomingDocument: Record "Incoming Document";
        Request: JsonObject;
        Response: JsonObject;
        TypeCode: Code[20];
        DefCode: Code[20];
    begin
        // [GIVEN] A type used by an incoming document.
        CreateType(TypeCode, DefCode);
        IncomingDocument.Init();
        IncomingDocument."Data Exchange Type" := TypeCode;
        IncomingDocument.Insert(true);
        Request.Add('code', TypeCode);
        Request.Add('expectedCount', 1);
        // [WHEN] Deletion is confirmed.
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Delete", Request, LanguageId);
        // [THEN] It is refused, names the usage, and everything survives.
        AssertRefusal(Response, 'PreconditionFailed');
        AssertLanguage(Fixture.ReadText(Response, 'error'), LanguageId, 'incoming document', 'innkomnum skjölum');
        LibraryAssert.IsTrue(Fixture.ReadText(Response, 'nextStep') <> '', 'A next step is given.');
        LibraryAssert.IsTrue(ExchangeType.Get(TypeCode), 'Type survives.');
        LibraryAssert.IsTrue(Definition.Get(DefCode), 'Definition survives.');
        // [CLEANUP]
        IncomingDocument.Delete(true);
        AssertSuccess(Dispatch("Message Type ori"::"DataExchange.Type.Delete", Request, LanguageId));
        Definition.Get(DefCode);
        Definition.Delete(true);
    end;

    local procedure CheckDefinitionKept(LanguageId: Integer)
    var
        Definition: Record "Data Exch. Def";
        Request: JsonObject;
        DefRequest: JsonObject;
        Response: JsonObject;
        TypeCode: Code[20];
        DefCode: Code[20];
    begin
        // [GIVEN] A type and its definition.
        CreateType(TypeCode, DefCode);
        DefRequest.Add('code', DefCode);
        // [WHEN] The definition is deleted first.
        Response := Dispatch("Message Type ori"::"DataExchange.Definition.Delete", DefRequest, LanguageId);
        // [THEN] The type blocks it.
        AssertRefusal(Response, 'PreconditionFailed');
        // [WHEN] The type is deleted.
        Request.Add('code', TypeCode);
        Request.Add('expectedCount', 1);
        AssertSuccess(Dispatch("Message Type ori"::"DataExchange.Type.Delete", Request, LanguageId));
        // [THEN] The definition is kept and can now be deleted with its own message type.
        LibraryAssert.IsTrue(Definition.Get(DefCode), 'Type delete never deletes the definition.');
        AssertSuccess(Dispatch("Message Type ori"::"DataExchange.Definition.Delete", DefRequest, LanguageId));
        LibraryAssert.IsFalse(Definition.Get(DefCode), 'Definition deleted afterwards.');
    end;

    local procedure CheckMissing(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Foundation's counted-confirmation gate runs first, so the missing code is reported once the count is confirmed.
        Request.Add('expectedCount', 1);
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Delete", Request, LanguageId);
        AssertRefusal(Response, 'MissingParameter');
        Request.Add('code', Fixture.NewCode('X199N'));
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Delete", Request, LanguageId);
        AssertRefusal(Response, 'RecordNotFound');
        AssertLanguage(Fixture.ReadText(Response, 'error'), LanguageId, 'was not found', 'fannst ekki');
    end;

    local procedure CreateType(var TypeCode: Code[20]; var DefCode: Code[20])
    var
        ExchangeType: Record "Data Exchange Type";
    begin
        DefCode := Fixture.CreateImportDefinition(0);
        TypeCode := Fixture.NewCode('X199');
        ExchangeType.Init();
        ExchangeType.Code := TypeCode;
        ExchangeType."Data Exch. Def. Code" := DefCode;
        ExchangeType.Insert(true);
    end;

    local procedure AssertSuccess(Response: JsonObject)
    begin
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Expected success. ' + Fixture.ReadText(Response, 'error'));
    end;

    local procedure AssertRefusal(Response: JsonObject; ErrorCode: Text)
    begin
        LibraryAssert.AreEqual('Error', Fixture.ReadText(Response, 'status'), 'Expected refusal.');
        LibraryAssert.AreEqual(ErrorCode, Fixture.ReadText(Response, 'code'), 'Stable refusal code. ' + Fixture.ReadText(Response, 'error'));
    end;

    local procedure AssertLanguage(Value: Text; LanguageId: Integer; English: Text; Icelandic: Text)
    begin
        if LanguageId = 1039 then
            LibraryAssert.IsTrue(Value.Contains(Icelandic), 'Expected Icelandic: ' + Value)
        else
            LibraryAssert.IsTrue(Value.Contains(English), 'Expected English: ' + Value);
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
        Commit();
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, TaskId, LanguageId, MessageId, ResponseContent, ContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        LibraryAssert.IsTrue(Response.ReadFrom(ResponseText), 'The public dispatcher returns JSON.');
    end;
}
