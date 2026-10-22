namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Contract completeness for every message type of Bifröst Attachments, the same bar Bifröst Foundation
/// holds its own types to. A type fails here when a required contract chapter is missing or empty, an
/// error has no machine code, a direction does not match the declared effect, a response field is not
/// described, a successful example does not match the declared response, or a discovery text is missing.
/// </summary>
codeunit 96265 "Storage Contract Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit "Library Assert";

    [Test]
    procedure EveryType_DeclaresEveryRequiredChapter()
    var
        Contract: Interface "Msg Contract ori";
        Ordinal: Integer;
        Offenders: Text;
    begin
        // [SCENARIO] Every chapter a caller needs is declared and holds content; metering is the only chapter an app may leave out.
        foreach Ordinal in AppOrdinals() do begin
            Contract := Enum::"Message Type ori".FromInteger(Ordinal);
            Offenders += ChapterOffenders(Contract, TypeName(Ordinal));
        end;
        LibraryAssert.AreEqual('', Offenders, 'Contract chapters: ' + Offenders);
    end;

    [Test]
    procedure EveryType_ErrorsCarryCodeWhenAndFix()
    var
        Contract: Interface "Msg Contract ori";
        Errors: JsonArray;
        EntryToken: JsonToken;
        Entry: JsonObject;
        Ordinal: Integer;
        CodeName: Text;
        Offenders: Text;
    begin
        // [SCENARIO] An error without a machine code, a condition or a next step cannot be acted on by a program or a reader.
        foreach Ordinal in AppOrdinals() do begin
            Contract := Enum::"Message Type ori".FromInteger(Ordinal);
            Clear(Errors);
            Contract.GetErrors(Errors);
            foreach EntryToken in Errors do begin
                Entry := EntryToken.AsObject();
                CodeName := ReadText(Entry, 'code');
                if CodeName = '' then
                    Offenders += TypeName(Ordinal) + '|error without code '
                else
                    if not Enum::"Bifrost Error Code ori".Names().Contains(CodeName) then
                        Offenders += TypeName(Ordinal) + '|unknown code ' + CodeName + ' ';
                if ReadText(Entry, 'when') = '' then
                    Offenders += TypeName(Ordinal) + '|error without condition ' + CodeName + ' ';
                if ReadText(Entry, 'fix') = '' then
                    Offenders += TypeName(Ordinal) + '|error without next step ' + CodeName + ' ';
            end;
        end;
        LibraryAssert.AreEqual('', Offenders, 'Error entries: ' + Offenders);
    end;

    [Test]
    procedure EveryType_DirectionMatchesEffect()
    var
        Contract: Interface "Msg Contract ori";
        MessageInterface: Interface "Msg Interface ori";
        Effect: JsonObject;
        Ordinal: Integer;
        EffectName: Text;
        Offenders: Text;
    begin
        // [SCENARIO] A write or irreversible type is Inbound, a read type is Outbound, and the effect names its changes and permission set.
        foreach Ordinal in AppOrdinals() do begin
            Contract := Enum::"Message Type ori".FromInteger(Ordinal);
            MessageInterface := Enum::"Message Type ori".FromInteger(Ordinal);
            Clear(Effect);
            Contract.GetEffect(Effect);
            EffectName := ReadText(Effect, 'effect');
            case EffectName of
                'read':
                    if MessageInterface.GetMessageDirection() <> Enum::"Msg Direction ori"::Outbound then
                        Offenders += TypeName(Ordinal) + '|read is not Outbound ';
                'write', 'irreversible':
                    if MessageInterface.GetMessageDirection() <> Enum::"Msg Direction ori"::Inbound then
                        Offenders += TypeName(Ordinal) + '|' + EffectName + ' is not Inbound ';
                else
                    Offenders += TypeName(Ordinal) + '|unknown effect ' + EffectName + ' ';
            end;
            if ReadText(Effect, 'changes') = '' then
                Offenders += TypeName(Ordinal) + '|effect without changes ';
            if ReadText(Effect, 'permissionSet') = '' then
                Offenders += TypeName(Ordinal) + '|effect without permission set ';
            if not Effect.Contains('idempotent') then
                Offenders += TypeName(Ordinal) + '|effect without idempotent ';
            if not Effect.Contains('preconditions') then
                Offenders += TypeName(Ordinal) + '|effect without preconditions ';
        end;
        LibraryAssert.AreEqual('', Offenders, 'Direction and effect: ' + Offenders);
    end;

    [Test]
    procedure EveryType_ResponseFieldsAreDescribed()
    var
        Contract: Interface "Msg Contract ori";
        Response: JsonObject;
        FieldsToken: JsonToken;
        FieldToken: JsonToken;
        ChildrenToken: JsonToken;
        Field: JsonObject;
        Ordinal: Integer;
        FieldName: Text;
        FieldType: Text;
        Offenders: Text;
    begin
        // [SCENARIO] Every response field has a name, a JSON type and a description; an object field and a list of rows describe their members.
        foreach Ordinal in AppOrdinals() do begin
            Contract := Enum::"Message Type ori".FromInteger(Ordinal);
            Clear(Response);
            Contract.GetResponse(Response);
            if not Response.Get('fields', FieldsToken) then
                Offenders += TypeName(Ordinal) + '|response without fields '
            else begin
                if FieldsToken.AsArray().Count() = 0 then
                    Offenders += TypeName(Ordinal) + '|response with no fields ';
                foreach FieldToken in FieldsToken.AsArray() do begin
                    Field := FieldToken.AsObject();
                    FieldName := ReadText(Field, 'name');
                    FieldType := ReadText(Field, 'type');
                    if (FieldName = '') or (FieldType = '') or (ReadText(Field, 'description') = '') then
                        Offenders += TypeName(Ordinal) + '|field ' + FieldName + ' lacks name, type or description ';
                    if (FieldType = 'object') or RowListFieldNames().Contains(FieldName) then
                        if not Field.Get('children', ChildrenToken) then
                            Offenders += TypeName(Ordinal) + '|field ' + FieldName + ' lacks children '
                        else
                            if ChildrenToken.AsArray().Count() = 0 then
                                Offenders += TypeName(Ordinal) + '|field ' + FieldName + ' has empty children ';
                end;
            end;
        end;
        LibraryAssert.AreEqual('', Offenders, 'Response chapter: ' + Offenders);
    end;

    [Test]
    procedure EveryType_HasSuccessExampleThatMatchesTheResponse()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        ChapterToken: JsonToken;
        ResponseChapterToken: JsonToken;
        FieldsChapterToken: JsonToken;
        ExampleToken: JsonToken;
        ResponseToken: JsonToken;
        DataToken: JsonToken;
        DeclaredNames: List of [Text];
        FieldToken: JsonToken;
        KeyName: Text;
        Ordinal: Integer;
        HasSuccess: Boolean;
        Offenders: Text;
    begin
        // [SCENARIO] A reader can see a real successful answer, and every key of it is declared in the response chapter.
        foreach Ordinal in AppOrdinals() do begin
            Clear(Contract);
            Clear(DeclaredNames);
            HasSuccess := false;
            ContractMgt.GetContract(Enum::"Message Type ori".FromInteger(Ordinal), Contract);
            if Contract.Get('response', ResponseChapterToken) then
                if ResponseChapterToken.AsObject().Get('fields', FieldsChapterToken) then
                    foreach FieldToken in FieldsChapterToken.AsArray() do
                        DeclaredNames.Add(ReadText(FieldToken.AsObject(), 'name'));
            if not Contract.Get('examples', ChapterToken) then
                Offenders += TypeName(Ordinal) + '|no examples '
            else
                foreach ExampleToken in ChapterToken.AsArray() do
                    if ExampleToken.AsObject().Get('response', ResponseToken) then
                        if ReadText(ResponseToken.AsObject(), 'status') = 'Success' then begin
                            HasSuccess := true;
                            if ResponseToken.AsObject().Get('data', DataToken) then
                                foreach KeyName in DataToken.AsObject().Keys() do
                                    if not DeclaredNames.Contains(KeyName) then
                                        Offenders += TypeName(Ordinal) + '|example key ' + KeyName + ' is not a declared response field ';
                        end;
            if not HasSuccess then
                Offenders += TypeName(Ordinal) + '|no successful example ';
        end;
        LibraryAssert.AreEqual('', Offenders, 'Examples: ' + Offenders);
    end;

    [Test]
    procedure EveryType_WorkflowStepsAndRelatedTypesExist()
    var
        Contract: Interface "Msg Contract ori";
        Workflow: JsonObject;
        Related: JsonArray;
        StepsToken: JsonToken;
        EntryToken: JsonToken;
        Ordinal: Integer;
        Offenders: Text;
    begin
        // [SCENARIO] A workflow step and a related type name a message type that exists, and a workflow has an explanation.
        foreach Ordinal in AppOrdinals() do begin
            Contract := Enum::"Message Type ori".FromInteger(Ordinal);
            Clear(Workflow);
            if Contract.GetWorkflow(Workflow) then begin
                if ReadText(Workflow, 'text') = '' then
                    Offenders += TypeName(Ordinal) + '|workflow without text ';
                if Workflow.Get('steps', StepsToken) then
                    foreach EntryToken in StepsToken.AsArray() do
                        if not Enum::"Message Type ori".Names().Contains(ReadText(EntryToken.AsObject(), 'messageType')) then
                            Offenders += TypeName(Ordinal) + '|workflow step ' + ReadText(EntryToken.AsObject(), 'messageType') + ' ';
            end;
            Clear(Related);
            Contract.GetRelated(Related);
            foreach EntryToken in Related do
                if not Enum::"Message Type ori".Names().Contains(ReadText(EntryToken.AsObject(), 'name')) then
                    Offenders += TypeName(Ordinal) + '|related ' + ReadText(EntryToken.AsObject(), 'name') + ' ';
        end;
        LibraryAssert.AreEqual('', Offenders, 'Workflow and related: ' + Offenders);
    end;

    [Test]
    procedure EveryType_HasDiscoveryTextsInBothLanguages()
    var
        Discovery: Interface "Msg Discovery ori";
        MessageInterface: Interface "Msg Interface ori";
        EnglishTexts: Dictionary of [Text, Text];
        Ordinal: Integer;
        SavedLanguage: Integer;
        Offenders: Text;
    begin
        // [SCENARIO] Description, selection description and keywords exist in English and have a different Icelandic text.
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        foreach Ordinal in AppOrdinals() do begin
            Discovery := Enum::"Message Type ori".FromInteger(Ordinal);
            MessageInterface := Enum::"Message Type ori".FromInteger(Ordinal);
            EnglishTexts.Add(TypeName(Ordinal) + '|description', MessageInterface.GetDescription());
            EnglishTexts.Add(TypeName(Ordinal) + '|selection description', Discovery.GetSelectionDescription());
            EnglishTexts.Add(TypeName(Ordinal) + '|keywords', Discovery.GetKeywords());
        end;
        GlobalLanguage(1039);
        foreach Ordinal in AppOrdinals() do begin
            Discovery := Enum::"Message Type ori".FromInteger(Ordinal);
            MessageInterface := Enum::"Message Type ori".FromInteger(Ordinal);
            Offenders += DiscoveryOffenders(EnglishTexts, TypeName(Ordinal) + '|description', MessageInterface.GetDescription());
            Offenders += DiscoveryOffenders(EnglishTexts, TypeName(Ordinal) + '|selection description', Discovery.GetSelectionDescription());
            Offenders += DiscoveryOffenders(EnglishTexts, TypeName(Ordinal) + '|keywords', Discovery.GetKeywords());
        end;
        GlobalLanguage(SavedLanguage);
        LibraryAssert.AreEqual('', Offenders, 'Discovery texts: ' + Offenders);
    end;

    local procedure DiscoveryOffenders(EnglishTexts: Dictionary of [Text, Text]; KeyText: Text; IcelandicText: Text): Text
    begin
        if EnglishTexts.Get(KeyText) = '' then
            exit(KeyText + ' has no English text ');
        if (IcelandicText = '') or (IcelandicText = EnglishTexts.Get(KeyText)) then
            exit(KeyText + ' has no Icelandic text ');
        exit('');
    end;

    local procedure ChapterOffenders(Contract: Interface "Msg Contract ori"; Name: Text) Offenders: Text
    var
        Envelope: JsonObject;
        Response: JsonObject;
        Effect: JsonObject;
        Workflow: JsonObject;
        Target: JsonArray;
        Parameters: JsonArray;
        Errors: JsonArray;
        Related: JsonArray;
        Examples: JsonArray;
        StepsToken: JsonToken;
        Overview: Text;
        Notes: Text;
    begin
        if not Contract.GetEnvelope(Envelope) then
            Offenders += Name + '|envelope ';
        if not Contract.GetTarget(Target) then begin
            if not TargetNotApplicable(Name) then
                Offenders += Name + '|target ';
        end else
            if Target.Count() = 0 then
                Offenders += Name + '|target is empty ';
        if not Contract.GetParameters(Parameters) then begin
            if not ParametersNotApplicable(Name) then
                Offenders += Name + '|parameters ';
        end else
            if (Parameters.Count() = 0) and not ParametersNotApplicable(Name) then
                Offenders += Name + '|parameters are empty ';
        if not Contract.GetResponse(Response) then
            Offenders += Name + '|response ';
        if not Contract.GetErrors(Errors) then
            Offenders += Name + '|errors '
        else
            if Errors.Count() = 0 then
                Offenders += Name + '|errors are empty ';
        if not Contract.GetEffect(Effect) then
            Offenders += Name + '|effect ';
        if not Contract.GetRelated(Related) then
            Offenders += Name + '|related '
        else
            if Related.Count() = 0 then
                Offenders += Name + '|related is empty ';
        if not Contract.GetWorkflow(Workflow) then begin
            if not Name.StartsWith('Help.') then
                Offenders += Name + '|workflow ';
        end else
            if not Workflow.Get('steps', StepsToken) then
                Offenders += Name + '|workflow without steps '
            else
                if StepsToken.AsArray().Count() = 0 then
                    Offenders += Name + '|workflow with no steps ';
        if not Contract.GetExamples(Examples) then
            Offenders += Name + '|examples '
        else
            if Examples.Count() = 0 then
                Offenders += Name + '|examples are empty ';
        if (not Contract.GetOverview(Overview)) or (Overview = '') then
            Offenders += Name + '|overview ';
        if (not Contract.GetNotes(Notes)) or (Notes = '') then
            Offenders += Name + '|notes ';
    end;

    // Types that identify no existing record: a list, a help guide, or a type that creates what it names.
    local procedure TargetNotApplicable(Name: Text): Boolean
    begin
        exit(Name in ['Storage.Account.List', 'Help.Storage.Get', 'Help.DataExchange.Get', 'Storage.Upload.Begin',
            'DataExchange.Definition.List', 'DataExchange.Entry.List', 'DataExchange.Type.List', 'DataExchange.Definition.Import']);
    end;

    // Types whose request carries no data.
    local procedure ParametersNotApplicable(Name: Text): Boolean
    begin
        exit(Name in ['Storage.Account.List', 'Help.Storage.Get', 'Help.DataExchange.Get', 'DataExchange.Type.List']);
    end;

    local procedure RowListFieldNames() Names: List of [Text]
    begin
        Names.AddRange('accounts', 'entries', 'definitions', 'types', 'lineDefs', 'columnDefs', 'mappings', 'fields', 'targets', 'warnings', 'processErrors');
    end;

    local procedure ReadText(Entry: JsonObject; PropertyName: Text): Text
    var
        ValueToken: JsonToken;
    begin
        if not Entry.Get(PropertyName, ValueToken) then
            exit('');
        if not ValueToken.IsValue() then
            exit('');
        exit(ValueToken.AsValue().AsText());
    end;

    local procedure AppOrdinals() Ordinals: List of [Integer]
    var
        Ordinal: Integer;
    begin
        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if (Ordinal >= 10035135) and (Ordinal <= 10035173) then
                Ordinals.Add(Ordinal);
        LibraryAssert.AreEqual(39, Ordinals.Count(), 'Bifröst Attachments declares 39 message types.');
    end;

    local procedure TypeName(Ordinal: Integer): Text
    var
        MessageType: Enum "Message Type ori";
    begin
        exit(MessageType.Names().Get(MessageType.Ordinals().IndexOf(Ordinal)));
    end;
}
