namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;

/// <summary>Verifies the message contracts delivered in the storage Batch 1 rollout.</summary>
codeunit 96215 "Storage Contract Batch1 Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

    [Test]
    procedure Batch1_AllTypes_HaveRequiredContractChapters()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        TypeName: Text;
        Chapter: Text;
    begin
        foreach TypeName in Batch1Types() do begin
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
            LibraryAssert.IsTrue(ContractMgt.GetContract(MessageType, Contract), TypeName + ' must declare a contract.');
            foreach Chapter in RequiredChapters(TypeName) do
                LibraryAssert.IsTrue(Contract.Contains(Chapter), TypeName + ' must declare chapter ' + Chapter + '.');
        end;
    end;

    [Test]
    procedure Batch1_Effects_MatchOperation()
    begin
        AssertEffect('Help.Storage.Get', 'read');
        AssertEffect('Storage.Account.List', 'read');
        AssertEffect('Storage.File.List', 'read');
        AssertEffect('Storage.File.Get', 'read');
        AssertEffect('Storage.File.Exists', 'read');
        AssertEffect('Storage.Directory.List', 'read');
        AssertEffect('Storage.Directory.Exists', 'read');
        AssertEffect('Storage.File.Create', 'irreversible');
        AssertEffect('Storage.File.Copy', 'irreversible');
        AssertEffect('Storage.File.Move', 'irreversible');
        AssertEffect('Storage.Directory.Create', 'irreversible');
        AssertEffect('Storage.File.Delete', 'irreversible');
        AssertEffect('Storage.Directory.Delete', 'irreversible');
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

    local procedure Batch1Types() Types: List of [Text]
    begin
        Types.Add('Help.Storage.Get');
        Types.Add('Storage.Account.List');
        Types.Add('Storage.File.List');
        Types.Add('Storage.File.Get');
        Types.Add('Storage.File.Create');
        Types.Add('Storage.File.Delete');
        Types.Add('Storage.File.Copy');
        Types.Add('Storage.File.Move');
        Types.Add('Storage.File.Exists');
        Types.Add('Storage.Directory.List');
        Types.Add('Storage.Directory.Create');
        Types.Add('Storage.Directory.Delete');
        Types.Add('Storage.Directory.Exists');
    end;

    local procedure RequiredChapters(TypeName: Text) Chapters: List of [Text]
    begin
        Chapters.Add('envelope');
        Chapters.Add('response');
        Chapters.Add('errors');
        Chapters.Add('effect');
        Chapters.Add('metering');
        Chapters.Add('related');
        if not (TypeName in ['Help.Storage.Get', 'Storage.Account.List']) then
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