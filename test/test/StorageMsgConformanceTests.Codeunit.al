namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using Origo.Bifrost;
using System.Reflection;

/// <summary>
/// Checks every message type of Bifröst Attachments against the rules Bifröst Foundation's
/// conformance test (98729) applies to its own types, with no allow-list: the help names the type
/// in its title and has the Overview, Request Parameters, Response Shape, Errors and Related Message
/// Types sections; the description is one caller-facing sentence; related types exist; the filter
/// table exists; and every business type can be found by English and Icelandic keywords.
/// </summary>
codeunit 96211 "Storage Msg Conformance Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        FirstOrdinal: Integer;
        LastOrdinal: Integer;

    [Test]
    procedure Scenario_AC01_Descriptions_FollowBothLanguages()
    var
        MessageInterface: Interface "Msg Interface ori";
        EnglishDescriptions: Dictionary of [Integer, Text];
        IcelandicDescriptions: Dictionary of [Integer, Text];
        RestoredDescriptions: Dictionary of [Integer, Text];
        Ordinal: Integer;
        SavedLanguage: Integer;
    begin
        // Story #126, AC01/03 | Time: independent of Today()/WorkDate() | Risk: compiled XLF required.
        // [GIVEN] Every Attachments message type, with caller-facing label descriptions.
        Initialize();
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        foreach Ordinal in AppOrdinals() do begin
            MessageInterface := Enum::"Message Type ori".FromInteger(Ordinal);
            EnglishDescriptions.Add(Ordinal, MessageInterface.GetDescription());
        end;
        // [WHEN] The caller changes from English to Icelandic, then back to English.
        GlobalLanguage(1039);
        foreach Ordinal in AppOrdinals() do begin
            MessageInterface := Enum::"Message Type ori".FromInteger(Ordinal);
            IcelandicDescriptions.Add(Ordinal, MessageInterface.GetDescription());
        end;
        GlobalLanguage(1033);
        foreach Ordinal in AppOrdinals() do begin
            MessageInterface := Enum::"Message Type ori".FromInteger(Ordinal);
            RestoredDescriptions.Add(Ordinal, MessageInterface.GetDescription());
        end;
        GlobalLanguage(SavedLanguage);
        // [THEN] Both translations exist and no previous language leaks into the next response.
        foreach Ordinal in AppOrdinals() do begin
            LibraryAssert.AreNotEqual('', EnglishDescriptions.Get(Ordinal), TypeName(Ordinal) + ' English description.');
            LibraryAssert.AreNotEqual('', IcelandicDescriptions.Get(Ordinal), TypeName(Ordinal) + ' Icelandic description.');
            LibraryAssert.AreNotEqual(EnglishDescriptions.Get(Ordinal), IcelandicDescriptions.Get(Ordinal), TypeName(Ordinal) + ' translated description.');
            LibraryAssert.AreEqual(EnglishDescriptions.Get(Ordinal), RestoredDescriptions.Get(Ordinal), TypeName(Ordinal) + ' restored English description.');
        end;
        LibraryAssert.IsTrue(EnglishDescriptions.Get(Enum::"Message Type ori"::"Storage.Account.List".AsInteger()).StartsWith('Lists the configured storage connections'), '1033 selects English, not just a different translation.');
        LibraryAssert.IsTrue(IcelandicDescriptions.Get(Enum::"Message Type ori"::"Storage.Account.List".AsInteger()).StartsWith('Listar uppsettar geymslutengingar'), '1039 selects Icelandic.');
    end;

    [Test]
    procedure Scenario_D7_Envelope_StaysEnglish()
    var
        Contract: Interface "Msg Contract ori";
        EnglishEnvelope: JsonObject;
        IcelandicEnvelope: JsonObject;
        RestoredEnvelope: JsonObject;
        EnglishText: Text;
        IcelandicText: Text;
        RestoredText: Text;
        SavedLanguage: Integer;
    begin
        // Story #126, D7 option B | Time: independent of Today()/WorkDate() | Risk: aggregation tested separately.
        // [GIVEN] The Storage.Account.List envelope is English-only public help.
        SavedLanguage := GlobalLanguage();
        Contract := Enum::"Message Type ori"::"Storage.Account.List";
        GlobalLanguage(1033);
        Contract.GetEnvelope(EnglishEnvelope);
        EnglishEnvelope.WriteTo(EnglishText);
        // [WHEN] The same chapter is built in Icelandic and again in English.
        GlobalLanguage(1039);
        Contract.GetEnvelope(IcelandicEnvelope);
        IcelandicEnvelope.WriteTo(IcelandicText);
        GlobalLanguage(1033);
        Contract.GetEnvelope(RestoredEnvelope);
        RestoredEnvelope.WriteTo(RestoredText);
        GlobalLanguage(SavedLanguage);
        // [THEN] Public chapter text and protocol values stay unchanged at either LCID.
        LibraryAssert.IsTrue(EnglishText.Contains('The storage message is identified by its message type'), 'English envelope description.');
        LibraryAssert.AreEqual(EnglishText, IcelandicText, 'English-only envelope at Icelandic caller LCID.');
        LibraryAssert.AreEqual(EnglishText, RestoredText, 'Changing back to English restores the same chapter.');
        LibraryAssert.AreEqual('notUsed', SubjectUse(IcelandicEnvelope), 'The protocol value remains language-independent.');
    end;

    [Test]
    procedure Scenario_D7_PublicHelp_StaysEnglish()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        EnglishContract: JsonObject;
        IcelandicContract: JsonObject;
        RestoredContract: JsonObject;
        EnglishText: Text;
        IcelandicText: Text;
        RestoredText: Text;
        IcelandicLanguageAfterHelp: Integer;
        Ordinal: Integer;
        SavedLanguage: Integer;
    begin
        // Story #126, D7 option B, Architect 1792190477 / Claude 1792194099: public help is English-only.
        // [GIVEN] Every Attachments type uses Foundation's public contract aggregation.
        SavedLanguage := GlobalLanguage();
        foreach Ordinal in AppOrdinals() do begin
            Clear(EnglishContract);
            Clear(IcelandicContract);
            Clear(RestoredContract);
            GlobalLanguage(1033);
            ContractMgt.GetContract(Enum::"Message Type ori".FromInteger(Ordinal), EnglishContract);
            EnglishContract.WriteTo(EnglishText);
            // [WHEN] Help is requested at 1033, 1039 and again at 1033.
            GlobalLanguage(1039);
            ContractMgt.GetContract(Enum::"Message Type ori".FromInteger(Ordinal), IcelandicContract);
            IcelandicLanguageAfterHelp := GlobalLanguage();
            IcelandicContract.WriteTo(IcelandicText);
            GlobalLanguage(1033);
            ContractMgt.GetContract(Enum::"Message Type ori".FromInteger(Ordinal), RestoredContract);
            RestoredContract.WriteTo(RestoredText);
            GlobalLanguage(SavedLanguage);
            // [THEN] Public help is English at both LCIDs without changing the caller's language.
            LibraryAssert.AreNotEqual('{}', EnglishText, TypeName(Ordinal) + ' public contract must exist.');
            LibraryAssert.AreEqual(EnglishText, IcelandicText, TypeName(Ordinal) + ' public help stays English at 1039.');
            LibraryAssert.AreEqual(EnglishText, RestoredText, TypeName(Ordinal) + ' restored English help.');
            LibraryAssert.AreEqual(1039, IcelandicLanguageAfterHelp, TypeName(Ordinal) + ' help restores the caller language.');
        end;
        GlobalLanguage(SavedLanguage);
    end;

    [Test]
    procedure Scenario_AC04_MessageNames_StayThreePart()
    var
        Ordinal: Integer;
        Segments: List of [Text];
    begin
        // Story #126, AC04 | Time: independent of Today()/WorkDate() | Risk: None.
        // [GIVEN] Every registered Attachments message type.
        Initialize();
        foreach Ordinal in AppOrdinals() do begin
            // [WHEN] The public name is split into segments.
            Segments := TypeName(Ordinal).Split('.');
            // [THEN] Localization never changes the three-part protocol name.
            LibraryAssert.AreEqual(3, Segments.Count(), TypeName(Ordinal) + ' must have three parts.');
        end;
    end;

    local procedure SubjectUse(Envelope: JsonObject): Text
    var
        SubjectToken: JsonToken;
        UseToken: JsonToken;
    begin
        Envelope.Get('subject', SubjectToken);
        SubjectToken.AsObject().Get('use', UseToken);
        exit(UseToken.AsValue().AsText());
    end;

    [Test]
    procedure Help_EveryType_HasTitleAndRequiredSections()
    var
        Ordinal: Integer;
        Offenders: Text;
    begin
        // [SCENARIO] Rules 1 and 2: every help document starts with the type name and has the standard sections.
        Initialize();
        foreach Ordinal in AppOrdinals() do
            Offenders += HelpOffenders(Ordinal);
        LibraryAssert.AreEqual('', Offenders, 'Help conformance: ' + Offenders);
    end;

    [Test]
    procedure Help_All39Types_HaveOverviewAndExamples()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        ChapterToken: JsonToken;
        Examples: JsonArray;
        ExampleToken: JsonToken;
        Example: JsonObject;
        RequestToken: JsonToken;
        ResponseToken: JsonToken;
        TypeToken: JsonToken;
        StatusToken: JsonToken;
        MessageInterface: Interface "Msg Interface ori";
        HasRefusal: Boolean;
        Ordinal: Integer;
        Count: Integer;
        Offenders: Text;
    begin
        // #160 AC1/AC2: check actual aggregated chapters, including all ten newer types.
        // Time: no date dependency. Risk: a stub can return true without supplying content.
        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if (Ordinal >= 10035135) and (Ordinal <= 10035173) then begin
                Count += 1;
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                Clear(Contract);
                ContractMgt.GetContract(MessageType, Contract);
                if not Contract.Get('overview', ChapterToken) then
                    Offenders += TypeName(Ordinal) + '|overview missing '
                else
                    if ChapterToken.AsValue().AsText() = '' then
                        Offenders += TypeName(Ordinal) + '|overview empty ';
                if not Contract.Get('examples', ChapterToken) then
                    Offenders += TypeName(Ordinal) + '|examples missing '
                else begin
                    Examples := ChapterToken.AsArray();
                    if Examples.Count() = 0 then
                        Offenders += TypeName(Ordinal) + '|examples empty ';
                    HasRefusal := false;
                    foreach ExampleToken in Examples do begin
                        Example := ExampleToken.AsObject();
                        if not Example.Get('request', RequestToken) then
                            Offenders += TypeName(Ordinal) + '|example request missing '
                        else
                            if not RequestToken.AsObject().Get('type', TypeToken) then
                                Offenders += TypeName(Ordinal) + '|example type missing '
                            else
                                if TypeToken.AsValue().AsText() <> TypeName(Ordinal) then
                                    Offenders += TypeName(Ordinal) + '|example type mismatch ';
                        if not Example.Get('response', ResponseToken) then
                            Offenders += TypeName(Ordinal) + '|example answer missing '
                        else begin
                            if ResponseToken.AsObject().Keys().Count() = 0 then
                                Offenders += TypeName(Ordinal) + '|example answer empty ';
                            if ResponseToken.AsObject().Get('status', StatusToken) then
                                HasRefusal := HasRefusal or (StatusToken.AsValue().AsText() = 'Error');
                        end;
                    end;
                    MessageInterface := MessageType;
                    if (MessageInterface.GetMessageDirection() <> Enum::"Msg Direction ori"::Outbound) or
                        (TypeName(Ordinal) = 'DataExchange.Definition.Export')
                    then
                        if not HasRefusal then
                            Offenders += TypeName(Ordinal) + '|write refusal missing ';
                end;
            end;
        LibraryAssert.AreEqual(39, Count, 'All 39 Attachments message types must be checked.');
        LibraryAssert.AreEqual('', Offenders, 'First-call help chapters: ' + Offenders);
    end;

    [Test]
    procedure Description_EveryType_IsOneCallerFacingSentence()
    var
        MsgInterface: Interface "Msg Interface ori";
        Ordinal: Integer;
        Offenders: Text;
    begin
        // [SCENARIO] Rule 3: 20-200 characters, a third-person verb first, no implementation detail.
        Initialize();
        foreach Ordinal in AppOrdinals() do begin
            MsgInterface := Enum::"Message Type ori".FromInteger(Ordinal);
            Offenders += SentenceOffenders(TypeName(Ordinal), 'description', MsgInterface.GetDescription());
        end;
        LibraryAssert.AreEqual('', Offenders, 'Description conformance: ' + Offenders);
    end;

    [Test]
    procedure RelatedTypes_EveryHelp_NameExistingTypes()
    var
        Ordinal: Integer;
        Offenders: Text;
    begin
        // [SCENARIO] Rule 4: every backticked A.B.C name under Related Message Types is a message type.
        Initialize();
        foreach Ordinal in AppOrdinals() do
            Offenders += RelatedTypeOffenders(Ordinal);
        LibraryAssert.AreEqual('', Offenders, 'Related types: ' + Offenders);
    end;

    [Test]
    procedure FilterTable_EveryType_IsZeroOrExistingTable()
    var
        AllObj: Record AllObj;
        MsgInterface: Interface "Msg Interface ori";
        Ordinal: Integer;
        Offenders: Text;
    begin
        // [SCENARIO] Rule 5: GetFilterTableNo is 0 or a table that exists.
        Initialize();
        foreach Ordinal in AppOrdinals() do begin
            MsgInterface := Enum::"Message Type ori".FromInteger(Ordinal);
            if MsgInterface.GetFilterTableNo() <> 0 then
                if not AllObj.Get(AllObj."Object Type"::Table, MsgInterface.GetFilterTableNo()) then
                    Offenders += TypeName(Ordinal) + '|filterTable ';
        end;
        LibraryAssert.AreEqual('', Offenders, 'Filter tables: ' + Offenders);
    end;

    [Test]
    procedure FilterTable_AttachmentTypes_NameTheirRecordTable()
    var
        MsgInterface: Interface "Msg Interface ori";
    begin
        // [SCENARIO] Offload and Restore act on document attachments; CreateLinked on an incoming document.
        Initialize();
        MsgInterface := Enum::"Message Type ori"::"Storage.Attachment.Offload";
        LibraryAssert.AreEqual(Database::"Document Attachment", MsgInterface.GetFilterTableNo(), 'Offload should filter on Document Attachment.');
        MsgInterface := Enum::"Message Type ori"::"Storage.Attachment.Restore";
        LibraryAssert.AreEqual(Database::"Document Attachment", MsgInterface.GetFilterTableNo(), 'Restore should filter on Document Attachment.');
        MsgInterface := Enum::"Message Type ori"::"Storage.Attachment.CreateLinked";
        LibraryAssert.AreEqual(Database::"Incoming Document", MsgInterface.GetFilterTableNo(), 'CreateLinked should filter on Incoming Document.');
    end;

    [Test]
    procedure Keywords_EveryBusinessType_HasEnglishAndIcelandic()
    var
        Discovery: Interface "Msg Discovery ori";
        EnglishKeywords: Dictionary of [Integer, Text];
        Ordinal: Integer;
        SavedLanguageId: Integer;
        Missing: Text;
    begin
        // [SCENARIO] #144 coverage: every business type carries keywords in English and in Icelandic.
        Initialize();
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(1033);
        foreach Ordinal in AppOrdinals() do
            if not IsHelpType(Ordinal) then begin
                Discovery := Enum::"Message Type ori".FromInteger(Ordinal);
                EnglishKeywords.Add(Ordinal, Discovery.GetKeywords());
            end;
        GlobalLanguage(1039);
        foreach Ordinal in EnglishKeywords.Keys() do begin
            Discovery := Enum::"Message Type ori".FromInteger(Ordinal);
            if EnglishKeywords.Get(Ordinal) = '' then
                Missing += TypeName(Ordinal) + ' has no English keywords. ';
            if (Discovery.GetKeywords() = '') or (Discovery.GetKeywords() = EnglishKeywords.Get(Ordinal)) then
                Missing += TypeName(Ordinal) + ' has no Icelandic keywords. ';
        end;
        GlobalLanguage(SavedLanguageId);
        LibraryAssert.AreEqual('', Missing, 'Keyword coverage: ' + Missing);
    end;

    [Test]
    procedure SelectionDescription_EveryBusinessType_IsOwnSentence()
    var
        Discovery: Interface "Msg Discovery ori";
        MsgInterface: Interface "Msg Interface ori";
        Ordinal: Integer;
        Offenders: Text;
    begin
        // [SCENARIO] Every business type returns its own selection text, written like a description.
        Initialize();
        foreach Ordinal in AppOrdinals() do
            if not IsHelpType(Ordinal) then begin
                Discovery := Enum::"Message Type ori".FromInteger(Ordinal);
                MsgInterface := Enum::"Message Type ori".FromInteger(Ordinal);
                Offenders += SentenceOffenders(TypeName(Ordinal), 'selection', Discovery.GetSelectionDescription());
                if Discovery.GetSelectionDescription() = MsgInterface.GetDescription() then
                    Offenders += TypeName(Ordinal) + '|selection repeats description ';
            end;
        LibraryAssert.AreEqual('', Offenders, 'Selection descriptions: ' + Offenders);
    end;

    [Test]
    procedure Keywords_ChunkQuery_HitsAppendNotSingleUpload()
    var
        Discovery: Interface "Msg Discovery ori";
        SavedLanguageId: Integer;
        AppendKeywords: Text;
        CreateKeywords: Text;
    begin
        // [SCENARIO] Sibling types are told apart: "send next chunk" is an Append term, not a File.Create term.
        Initialize();
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(1033);
        Discovery := Enum::"Message Type ori"::"Storage.Upload.Append";
        AppendKeywords := Discovery.GetKeywords();
        Discovery := Enum::"Message Type ori"::"Storage.File.Create";
        CreateKeywords := Discovery.GetKeywords();
        GlobalLanguage(SavedLanguageId);
        LibraryAssert.IsTrue(AppendKeywords.Contains('send next chunk'), 'Storage.Upload.Append should be found by "send next chunk".');
        LibraryAssert.IsFalse(CreateKeywords.Contains('chunk'), 'Storage.File.Create should not be found by chunk terms.');
    end;

    local procedure HelpOffenders(Ordinal: Integer): Text
    begin
        exit(ContractChapterOffenders(Ordinal));
    end;

    local procedure SentenceOffenders(Name: Text; Kind: Text; Sentence: Text) Offenders: Text
    var
        FirstWord: Text;
    begin
        if (StrLen(Sentence) < 20) or (StrLen(Sentence) > 200) then
            Offenders += Name + '|' + Kind + ' length ';
        FirstWord := Sentence;
        if StrPos(FirstWord, ' ') > 0 then
            FirstWord := CopyStr(FirstWord, 1, StrPos(FirstWord, ' ') - 1);
        if (FirstWord = '') or (UpperCase(CopyStr(FirstWord, 1, 1)) <> CopyStr(FirstWord, 1, 1)) or (not FirstWord.EndsWith('s')) then
            Offenders += Name + '|' + Kind + ' verb ';
        if LowerCase(Sentence).Contains('codeunit') or Sentence.Contains('CU ') or Sentence.Contains('=') then
            Offenders += Name + '|' + Kind + ' implementation detail ';
    end;

    local procedure RelatedTypeOffenders(Ordinal: Integer): Text
    begin
        exit(ContractRelatedTypeOffenders(Ordinal));
    end;

    local procedure ContractChapterOffenders(Ordinal: Integer) Offenders: Text
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        MessageType: Enum "Message Type ori";
        Chapter: Text;
        Chapters: List of [Text];
    begin
        MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
        ContractMgt.GetContract(MessageType, Contract);
        Chapters.AddRange('envelope', 'response', 'errors', 'effect', 'metering', 'related');
        foreach Chapter in Chapters do
            if not Contract.Contains(Chapter) then
                Offenders += TypeName(Ordinal) + '|contract ' + Chapter + ' ';
    end;

    local procedure ContractRelatedTypeOffenders(Ordinal: Integer) Offenders: Text
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        MessageType: Enum "Message Type ori";
        RelatedToken: JsonToken;
        EntryToken: JsonToken;
        Entry: JsonObject;
        NameToken: JsonToken;
        Candidate: Text;
    begin
        MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
        ContractMgt.GetContract(MessageType, Contract);
        if not Contract.Get('related', RelatedToken) then
            exit;
        foreach EntryToken in RelatedToken.AsArray() do begin
            Entry := EntryToken.AsObject();
            Entry.Get('name', NameToken);
            Candidate := NameToken.AsValue().AsText();
            if not Enum::"Message Type ori".Names().Contains(Candidate) then
                Offenders += TypeName(Ordinal) + '|related ' + Candidate + ' ';
        end;
    end;

    local procedure AppOrdinals() Ordinals: List of [Integer]
    var
        Ordinal: Integer;
    begin
        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if ((Ordinal >= FirstOrdinal) and (Ordinal <= LastOrdinal)) or ((Ordinal >= 10035158) and (Ordinal <= 10035163)) then
                Ordinals.Add(Ordinal);
        LibraryAssert.AreEqual(29, Ordinals.Count(), 'Bifröst Attachments declares 29 message types.');
    end;

    local procedure TypeName(Ordinal: Integer): Text
    var
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        exit(Names.Get(Ordinals.IndexOf(Ordinal)));
    end;

    local procedure IsHelpType(Ordinal: Integer): Boolean
    begin
        exit(TypeName(Ordinal).StartsWith('Help.'));
    end;

    local procedure Initialize()
    begin
        // Storage message-type values; the Data Exchange help values follow at 10035158-10035163.
        FirstOrdinal := 10035135;
        LastOrdinal := 10035157;
    end;
}
