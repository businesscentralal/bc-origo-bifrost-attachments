namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;

/// <summary>Issue 130: write and irreversible contracts are inbound in every language.</summary>
codeunit 96229 "Storage Direction130 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

    /// <summary>AC01: every Storage write or irreversible type is inbound in English.</summary>
    [Test]
    procedure Scenario_AC01_StorageWritesAreInbound1033()
    begin
        AssertDirection(1033, true, 'AC01 1033');
    end;

    /// <summary>AC01: every Storage write or irreversible type is inbound in Icelandic.</summary>
    [Test]
    procedure Scenario_AC01_StorageWritesAreInbound1039()
    begin
        AssertDirection(1039, true, 'AC01 1039');
    end;

    /// <summary>AC02: every Attachments type matches its contract effect in English.</summary>
    [Test]
    procedure Scenario_AC02_AllTypesMatchEffect1033()
    begin
        AssertDirection(1033, false, 'AC02 1033');
    end;

    /// <summary>AC02: every Attachments type matches its contract effect in Icelandic.</summary>
    [Test]
    procedure Scenario_AC02_AllTypesMatchEffect1039()
    begin
        AssertDirection(1039, false, 'AC02 1039');
    end;

    local procedure AssertDirection(LanguageId: Integer; StorageWritesOnly: Boolean; Scenario: Text)
    var
        Problems: Text;
        SavedLanguageId: Integer;
    begin
        // [GIVEN] The requested language and the shipped message contracts.
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(LanguageId);
        // [WHEN] Direction is read from each implementation and compared with the contract effect.
        Problems := DirectionProblems(StorageWritesOnly);
        GlobalLanguage(SavedLanguageId);
        // [THEN] Write and irreversible effects are Inbound. Read effects are Outbound.
        LibraryAssert.AreEqual('', Problems, Scenario);
    end;

    local procedure DirectionProblems(StorageWritesOnly: Boolean) Problems: Text
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        MsgInterface: Interface "Msg Interface ori";
        Contract: JsonObject;
        Effect: JsonObject;
        EffectToken: JsonToken;
        Names: List of [Text];
        Ordinals: List of [Integer];
        DirectionNames: List of [Text];
        DirectionOrdinals: List of [Integer];
        TypeName: Text;
        EffectName: Text;
        DirectionName: Text;
        Index: Integer;
        Checked: Integer;
        StorageWrites: Integer;
        NamedWrites: Integer;
    begin
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        DirectionNames := Enum::"Msg Direction ori".Names();
        DirectionOrdinals := Enum::"Msg Direction ori".Ordinals();
        for Index := 1 to Names.Count() do begin
            TypeName := Names.Get(Index);
            if not IsAttachmentsType(TypeName) then
                continue;
            MessageType := Enum::"Message Type ori".FromInteger(Ordinals.Get(Index));
            MsgInterface := MessageType;
            if not ContractMgt.GetContract(MessageType, Contract) then begin
                Problems += TypeName + ' has no contract; ';
                continue;
            end;
            if not Contract.Get('effect', EffectToken) then begin
                Problems += TypeName + ' has no effect chapter; ';
                continue;
            end;
            Effect := EffectToken.AsObject();
            if not Effect.Get('effect', EffectToken) then begin
                Problems += TypeName + ' has no effect value; ';
                continue;
            end;
            EffectName := EffectToken.AsValue().AsText();
            DirectionName := DirectionNames.Get(DirectionOrdinals.IndexOf(MsgInterface.GetMessageDirection().AsInteger()));
            if StorageWritesOnly and not IsStorageWrite(TypeName, EffectName) then
                continue;
            if not StorageWritesOnly then
                Checked += 1;
            if IsStorageWrite(TypeName, EffectName) then
                StorageWrites += 1;
            if IsNamedStorageWrite(TypeName) then
                NamedWrites += 1;
            if (EffectName in ['write', 'irreversible']) and (DirectionName <> 'Inbound') then
                Problems += TypeName + ' effect ' + EffectName + ' direction ' + DirectionName + '; ';
            if (EffectName = 'read') and (DirectionName <> 'Outbound') then
                Problems += TypeName + ' effect read direction ' + DirectionName + '; ';
            if not (EffectName in ['read', 'write', 'irreversible']) then
                Problems += TypeName + ' unknown effect ' + EffectName + '; ';
        end;
        // #24 added Storage.Upload.CommitToDataExchange.
        if StorageWrites <> 16 then
            Problems += 'storage write count ' + Format(StorageWrites) + '; ';
        if NamedWrites <> 6 then
            Problems += 'named storage write count ' + Format(NamedWrites) + '; ';
        // #24, #25 and #26 added five types.
        if (not StorageWritesOnly) and (Checked <> 39) then
            Problems += 'attachments type count ' + Format(Checked) + '; ';
    end;

    local procedure IsAttachmentsType(TypeName: Text): Boolean
    begin
        exit(TypeName.StartsWith('Storage.') or TypeName.StartsWith('DataExchange.') or TypeName.StartsWith('Help.Storage.') or TypeName.StartsWith('Help.DataExchange.'));
    end;

    local procedure IsStorageWrite(TypeName: Text; EffectName: Text): Boolean
    begin
        exit(TypeName.StartsWith('Storage.') and (EffectName in ['write', 'irreversible']));
    end;

    local procedure IsNamedStorageWrite(TypeName: Text): Boolean
    begin
        exit(TypeName in [
            'Storage.File.Create',
            'Storage.File.Delete',
            'Storage.File.Copy',
            'Storage.File.Move',
            'Storage.Directory.Create',
            'Storage.Directory.Delete']);
    end;
}
