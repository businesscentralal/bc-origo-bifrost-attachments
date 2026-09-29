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

    local procedure HelpOffenders(Ordinal: Integer) Offenders: Text
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

    local procedure RelatedTypeOffenders(Ordinal: Integer) Offenders: Text
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

    local procedure IsTypeLikeName(Candidate: Text): Boolean
    begin
        if Candidate.Contains(' ') then
            exit(false);
        exit(Candidate.Split('.').Count() = 3);
    end;

    local procedure HelpOf(Ordinal: Integer): Text
    var
        TempArgument: Record "Message Argument ori";
        MsgInterface: Interface "Msg Interface ori";
        SavedLanguageId: Integer;
    begin
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(1033);
        TempArgument.Init();
        TempArgument."Type" := Enum::"Message Type ori".FromInteger(Ordinal);
        TempArgument.Insert(true);
        MsgInterface := TempArgument.GetMessageTypeInterface();
        MsgInterface.GetMessageHelpAsMarkdownDocument(TempArgument);
        GlobalLanguage(SavedLanguageId);
        exit(TempArgument.GetResponseText());
    end;

    local procedure AppOrdinals() Ordinals: List of [Integer]
    var
        Ordinal: Integer;
    begin
        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if ((Ordinal >= FirstOrdinal) and (Ordinal <= LastOrdinal)) or ((Ordinal >= 70013510) and (Ordinal <= 70013515)) then
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

    local procedure LineFeed(): Text
    var
        Character: Text[1];
    begin
        Character[1] := 10;
        exit(Character);
    end;

    local procedure Initialize()
    begin
        // The app's object-id block; the enum-extension values live in the same numbers.
        FirstOrdinal := 10035635;
        LastOrdinal := 10035684;
    end;
}
