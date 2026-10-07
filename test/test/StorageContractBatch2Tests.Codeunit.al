namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using System.IO;

/// <summary>Verifies the message contracts delivered in the storage Batch 2 rollout.</summary>
codeunit 96216 "Storage Contract Batch2 Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

    [Test]
    procedure Batch2_AllTypes_HaveRequiredContractChapters()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        TypeName: Text;
        Chapter: Text;
    begin
        foreach TypeName in Batch2Types() do begin
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
            LibraryAssert.IsTrue(ContractMgt.GetContract(MessageType, Contract), TypeName + ' must declare a contract.');
            foreach Chapter in RequiredChapters(TypeName) do
                LibraryAssert.IsTrue(Contract.Contains(Chapter), TypeName + ' must declare chapter ' + Chapter + '.');
        end;
    end;

    [Test]
    procedure Batch2_Effects_MatchOperation()
    begin
        AssertEffect('DataExchange.Definition.List', 'read');
        AssertEffect('DataExchange.Definition.Get', 'read');
        AssertEffect('DataExchange.Type.List', 'read');
        AssertEffect('DataExchange.Entry.List', 'read');
        AssertEffect('DataExchange.Entry.Get', 'read');
        AssertEffect('Storage.Upload.Status', 'read');
        AssertEffect('Storage.Attachment.Offload', 'irreversible');
        AssertEffect('Storage.Attachment.CreateLinked', 'write');
        AssertEffect('Storage.Attachment.CreateForRecord', 'write');
        AssertEffect('Storage.Upload.Begin', 'write');
        AssertEffect('Storage.Upload.Append', 'write');
        AssertEffect('Storage.Upload.Commit', 'irreversible');
        AssertEffect('Storage.Upload.CommitToRecord', 'write');
        AssertEffect('Storage.Upload.Abort', 'write');
        AssertEffect('Storage.Attachment.Restore', 'irreversible');
    end;


    /// <summary>Verifies actual Foundation contracts omit unused storage requirements.</summary>
    [Test]
    procedure Scenario_AC02_QueryContracts_DoNotRequireStorage()
    var
        TypeName: Text;
        Types: List of [Text];
    begin
        // Story #69, AC02 | Time: None | Risk: Foundation contract dispatch
        Types.Add('Storage.Account.List');
        Types.Add('DataExchange.Type.List');
        foreach TypeName in Types do
            LibraryAssert.AreEqual(0, ContractParameters(TypeName).Count(), TypeName + ' has no parameters.');
        AssertParameterAbsent('DataExchange.Definition.List', 'storageCode');
        AssertParameterAbsent('DataExchange.Entry.List', 'storageCode');
        AssertParameter('Storage.Upload.Begin', 'storageCode', false);
        AssertParameterAbsent('Storage.Upload.CommitToRecord', 'storageCode');
    end;

    /// <summary>Preserves conditional storage, source and addressing aliases.</summary>
    [Test]
    procedure Scenario_AC02_AttachmentContracts_DeclareAcceptedAliases()
    begin
        // Story #69, AC02 | Time: None | Risk: Held #11 behavior is not asserted
        AssertParameter('Storage.Attachment.CreateForRecord', 'storageCode', false);
        AssertParameter('Storage.Attachment.CreateForRecord', 'sourceTarget', false);
        AssertParameter('Storage.Attachment.CreateForRecord', 'sourceSystemId', false);
        AssertParameter('Storage.Attachment.CreateForRecord', 'content', false);
        AssertParameter('Storage.Attachment.CreateForRecord', 'contentBase64', false);
        AssertParameter('Storage.Upload.CommitToRecord', 'tableName', false);
        AssertParameter('Storage.Upload.CommitToRecord', 'description', false);
    end;

    /// <summary>A seeded definition can be queried without storageCode.</summary>
    [Test]
    procedure Scenario_AC04_DefinitionList_NoStorage_ReturnsSeededRow()
    var
        Definition: Record "Data Exch. Def";
        Response: JsonObject;
        Request: JsonObject;
        DataObject: JsonObject;
        Row: JsonObject;
        Token: JsonToken;
        Rows: JsonArray;
        Found: Boolean;
    begin
        // Story #69, AC04 | Time: None | Risk: Real persisted Foundation dispatch
        if Definition.Get('BIFT69-READ') then
            Definition.Delete(true);
        Definition.Init();
        Definition.Code := 'BIFT69-READ';
        Definition.Name := 'Contract query fixture';
        Definition.Insert(true);
        Response := Dispatch('DataExchange.Definition.List', Request, 1033);
        LibraryAssert.AreEqual('Success', JsonText(Response, 'status'), 'List without storageCode.');
        Response.Get('data', Token);
        DataObject := Token.AsObject();
        DataObject.Get('definitions', Token);
        Rows := Token.AsArray();
        foreach Token in Rows do begin
            Row := Token.AsObject();
            if JsonText(Row, 'code') = Definition.Code then
                Found := true;
        end;
        LibraryAssert.IsTrue(Found, 'The dispatched query must return the seeded definition.');
    end;

    /// <summary>All malformed filters are reported together before querying records.</summary>
    [Test]
    procedure Scenario_AC04_DefinitionFilters_Malformed_ReturnCompleteErrors()
    var
        Response: JsonObject;
        Request: JsonObject;
    begin
        // Story #69, AC04 | Time: None | Risk: Real Foundation error collector
        Request.ReadFrom('{"type":{},"direction":null}');
        Response := Dispatch('DataExchange.Definition.List', Request, 1033);
        AssertMultiple(Response, 2);
        AssertProblem(Response, 'type', 'InvalidParameterFormat');
        AssertProblem(Response, 'direction', 'InvalidParameterFormat');
    end;

    /// <summary>Unsupported names carry an expected value and actionable next step.</summary>
    [Test]
    procedure Scenario_AC04_DefinitionFilters_Unknown_ReturnCompleteErrors()
    var
        Response: JsonObject;
        Request: JsonObject;
    begin
        // Story #69, AC04 | Time: None | Risk: Real Foundation error collector
        Request.ReadFrom('{"type":"not-a-type","direction":"sideways"}');
        Response := Dispatch('DataExchange.Definition.List', Request, 1033);
        AssertMultiple(Response, 2);
        AssertProblem(Response, 'type', 'InvalidParameter');
        AssertProblem(Response, 'direction', 'InvalidParameter');
    end;

    /// <summary>Null/object/array flags and invalid entry numbers never use defaults.</summary>
    [Test]
    procedure Scenario_AC04_EntryGet_InvalidInputs_CollectsEveryProblem()
    var
        Response: JsonObject;
        Request: JsonObject;
        RawRequest: Text;
        Requests: List of [Text];
    begin
        // Story #69, AC04 | Time: None | Risk: No early success or skipped assertions
        Requests.Add('{"entryNo":null,"includeFields":{},"includeFileContent":[]}');
        Requests.Add('{"entryNo":1.5,"includeFields":null,"includeFileContent":"false"}');
        foreach RawRequest in Requests do begin
            Request.ReadFrom(RawRequest);
            Response := Dispatch('DataExchange.Entry.Get', Request, 1033);
            AssertMultiple(Response, 3);
            AssertProblem(Response, 'entryNo', 'InvalidParameterFormat');
            AssertProblem(Response, 'includeFields', 'InvalidParameterFormat');
            AssertProblem(Response, 'includeFileContent', 'InvalidParameterFormat');
        end;
    end;

    /// <summary>Entry filters collect bad dates, definition codes and paging values.</summary>
    [Test]
    procedure Scenario_AC04_EntryList_MalformedInputs_ReturnsFiveErrors()
    var
        Response: JsonObject;
        Request: JsonObject;
    begin
        // Story #69, AC04 | Time: None | Risk: Foundation paging values are prevalidated
        Request.ReadFrom('{"skip":-1,"take":1001,"dateFrom":{},"dateTo":null,"dataExchDefCode":[]}');
        Response := Dispatch('DataExchange.Entry.List', Request, 1033);
        AssertMultiple(Response, 5);
        AssertProblem(Response, 'skip', 'InvalidParameter');
        AssertProblem(Response, 'take', 'InvalidParameter');
        AssertProblem(Response, 'dateFrom', 'InvalidParameterFormat');
        AssertProblem(Response, 'dateTo', 'InvalidParameterFormat');
        AssertProblem(Response, 'dataExchDefCode', 'InvalidParameterFormat');
    end;

    /// <summary>Valid zero paging retains Foundation's documented default.</summary>
    [Test]
    procedure Scenario_AC04_EntryList_ZeroTake_PreservesDefault()
    var
        Response: JsonObject;
        Request: JsonObject;
        Token: JsonToken;
        DataObject: JsonObject;
    begin
        // Story #69, AC04 | Time: None | Risk: Foundation default paging contract
        Request.ReadFrom('{"skip":0,"take":0}');
        Response := Dispatch('DataExchange.Entry.List', Request, 1033);
        LibraryAssert.AreEqual('Success', JsonText(Response, 'status'), 'Zero take is valid.');
        Response.Get('data', Token);
        DataObject := Token.AsObject();
        DataObject.Get('take', Token);
        LibraryAssert.AreEqual(100, Token.AsValue().AsInteger(), 'Foundation default is preserved.');
    end;

    /// <summary>Invalid date range is an actionable refusal.</summary>
    [Test]
    procedure Scenario_AC04_EntryList_ReversedDates_Refused()
    var
        Response: JsonObject;
        Request: JsonObject;
    begin
        // Story #69, AC04 | Time: Invariant fixed dates | Risk: No WorkDate dependency
        Request.ReadFrom('{"dateFrom":"2026-10-07","dateTo":"2026-10-06"}');
        Response := Dispatch('DataExchange.Entry.List', Request, 1033);
        AssertProblem(Response, 'dateFrom', 'InvalidParameter');
    end;

    /// <summary>Overlong codes never select the record at the truncated prefix.</summary>
    [Test]
    procedure Scenario_AC04_DefinitionGet_CodeBoundary_NoTruncation()
    var
        Definition: Record "Data Exch. Def";
        Response: JsonObject;
        Request: JsonObject;
    begin
        // Story #69, AC04 | Time: None | Risk: Exact code boundary and read-back
        if Definition.Get('12345678901234567890') then
            Definition.Delete(true);
        Definition.Init();
        Definition.Code := '12345678901234567890';
        Definition.Name := 'Exact boundary';
        Definition.Insert(true);
        Request.Add('code', Definition.Code);
        Response := Dispatch('DataExchange.Definition.Get', Request, 1033);
        LibraryAssert.AreEqual('Success', JsonText(Response, 'status'), '20-character code must work.');
        Clear(Request);
        Request.Add('code', '123456789012345678901');
        Response := Dispatch('DataExchange.Definition.Get', Request, 1033);
        AssertProblem(Response, 'code', 'InvalidParameter');
        Definition.Get('12345678901234567890');
        LibraryAssert.AreEqual('Exact boundary', Definition.Name, 'The record is unchanged.');
    end;

    /// <summary>Missing code has all Foundation error details.</summary>
    [Test]
    procedure Scenario_AC04_DefinitionGet_MissingCode_CompleteRefusal()
    var
        Response: JsonObject;
        Request: JsonObject;
    begin
        // Story #69, AC04 | Time: None | Risk: Foundation omits empty error details
        Response := Dispatch('DataExchange.Definition.Get', Request, 1033);
        AssertProblem(Response, 'code', 'MissingParameter');
    end;

    /// <summary>Both supported languages carry a real localized error and next step.</summary>
    [Test]
    procedure Scenario_AC04_InvalidDirection_BilingualRefusals()
    var
        Request: JsonObject;
        English: JsonObject;
        Icelandic: JsonObject;
    begin
        // Story #69, AC04 | Time: None | Risk: Requires integrated final #71 XLF
        Request.Add('direction', 'sideways');
        English := Dispatch('DataExchange.Definition.List', Request, 1033);
        Icelandic := Dispatch('DataExchange.Definition.List', Request, 1039);
        AssertProblem(English, 'direction', 'InvalidParameter');
        AssertProblem(Icelandic, 'direction', 'InvalidParameter');
        LibraryAssert.AreNotEqual(JsonText(English, 'message'), JsonText(Icelandic, 'message'), 'Refusal must be translated.');
        LibraryAssert.AreNotEqual(JsonText(English, 'nextStep'), JsonText(Icelandic, 'nextStep'), 'Action must be translated.');
    end;

    local procedure ContractParameters(TypeName: Text) Parameters: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(ContractMgt.GetContract(Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName)), Contract), 'Registered contract is required.');
        if Contract.Get('parameters', Token) then
            Parameters := Token.AsArray();
    end;

    local procedure AssertParameter(TypeName: Text; ParameterName: Text; Required: Boolean)
    var
        Parameters: JsonArray;
        Token: JsonToken;
        RequiredToken: JsonToken;
        Entry: JsonObject;
        Found: Boolean;
    begin
        Parameters := ContractParameters(TypeName);
        foreach Token in Parameters do begin
            Entry := Token.AsObject();
            if JsonText(Entry, 'name') = ParameterName then begin
                Found := true;
                Entry.Get('required', RequiredToken);
                LibraryAssert.AreEqual(Required, RequiredToken.AsValue().AsBoolean(), 'Requiredness of ' + ParameterName);
                LibraryAssert.IsTrue(JsonText(Entry, 'description') <> '', 'Conditional usage must be described.');
            end;
        end;
        LibraryAssert.IsTrue(Found, TypeName + ' must declare ' + ParameterName);
    end;

    local procedure AssertParameterAbsent(TypeName: Text; ParameterName: Text)
    var
        Token: JsonToken;
        Parameters: JsonArray;
    begin
        Parameters := ContractParameters(TypeName);
        foreach Token in Parameters do
            LibraryAssert.AreNotEqual(ParameterName, JsonText(Token.AsObject(), 'name'), TypeName + ' must not declare ' + ParameterName);
    end;

    local procedure Dispatch(TypeName: Text; Request: JsonObject; LanguageId: Integer) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseText: Text;
        ResponseContentType: Text[100];
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        MessageVersion: Enum "Message Version ori";
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Commit(); // Persist fixtures before Foundation invokes its task codeunit.
        Dispatcher.EnqueueAndProcess(Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName)), MessageVersion, '', '', 'application/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        LibraryAssert.IsTrue(Response.ReadFrom(ResponseText), 'Foundation must return a JSON response.');
    end;

    local procedure AssertMultiple(Response: JsonObject; ExpectedCount: Integer)
    var
        Token: JsonToken;
    begin
        LibraryAssert.AreEqual('Error', JsonText(Response, 'status'), 'Error response required.');
        LibraryAssert.AreEqual('MultipleErrors', JsonText(Response, 'code'), 'All errors must be collected.');
        LibraryAssert.IsTrue(Response.Get('errors', Token), 'errors array required.');
        LibraryAssert.AreEqual(ExpectedCount, Token.AsArray().Count(), 'Exact problem count.');
    end;

    local procedure AssertProblem(Response: JsonObject; ParameterName: Text; ErrorCode: Text)
    var
        Token: JsonToken;
        ErrorToken: JsonToken;
        Errors: JsonArray;
        Problem: JsonObject;
        Found: Boolean;
    begin
        LibraryAssert.AreEqual('Error', JsonText(Response, 'status'), 'Error response required.');
        if Response.Get('errors', Token) then
            Errors := Token.AsArray()
        else
            Errors.Add(Response);
        foreach ErrorToken in Errors do begin
            Problem := ErrorToken.AsObject();
            if JsonText(Problem, 'parameter') = ParameterName then begin
                Found := true;
                LibraryAssert.AreEqual(ErrorCode, JsonText(Problem, 'code'), 'Stable error code.');
                LibraryAssert.IsTrue(JsonText(Problem, 'message') <> '', 'Localized message.');
                LibraryAssert.IsTrue(JsonText(Problem, 'received') <> '', 'Received value or explicit absence marker.');
                LibraryAssert.IsTrue(JsonText(Problem, 'expected') <> '', 'Expected format/value.');
                LibraryAssert.IsTrue(JsonText(Problem, 'nextStep') <> '', 'Actionable next step.');
            end;
        end;
        LibraryAssert.IsTrue(Found, 'Missing error for ' + ParameterName);
    end;

    local procedure JsonText(DataObject: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(DataObject.Get(PropertyName, Token), 'Missing JSON property ' + PropertyName);
        exit(Token.AsValue().AsText());
    end;

    local procedure AssertEffect(TypeName: Text; Expected: Text)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Effect: JsonObject;
        EffectToken: JsonToken;
    begin
        MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
        ContractMgt.GetContract(MessageType, Contract);
        Contract.Get('effect', EffectToken);
        Effect := EffectToken.AsObject();
        Effect.Get('effect', EffectToken);
        LibraryAssert.AreEqual(Expected, EffectToken.AsValue().AsText(), TypeName + ' effect mismatch.');
    end;

    local procedure Batch2Types() Types: List of [Text]
    begin
        Types.Add('Help.DataExchange.Get');
        Types.Add('DataExchange.Definition.List');
        Types.Add('DataExchange.Definition.Get');
        Types.Add('DataExchange.Type.List');
        Types.Add('DataExchange.Entry.List');
        Types.Add('DataExchange.Entry.Get');
        Types.Add('Storage.Attachment.Offload');
        Types.Add('Storage.Attachment.Restore');
        Types.Add('Storage.Attachment.CreateLinked');
        Types.Add('Storage.Attachment.CreateForRecord');
        Types.Add('Storage.Upload.Begin');
        Types.Add('Storage.Upload.Append');
        Types.Add('Storage.Upload.Commit');
        Types.Add('Storage.Upload.Abort');
        Types.Add('Storage.Upload.Status');
        Types.Add('Storage.Upload.CommitToRecord');
    end;

    local procedure RequiredChapters(TypeName: Text) Chapters: List of [Text]
    begin
        Chapters.Add('envelope');
        Chapters.Add('response');
        Chapters.Add('errors');
        Chapters.Add('effect');
        Chapters.Add('metering');
        Chapters.Add('related');
        if not (TypeName in ['Help.DataExchange.Get', 'DataExchange.Type.List']) then
            Chapters.Add('parameters');
    end;

    local procedure OrdinalOf(TypeName: Text): Integer
    var
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        exit(Ordinals.Get(Names.IndexOf(TypeName)));
    end;
}
