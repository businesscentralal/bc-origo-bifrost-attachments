namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;

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
        AssertEffect('Storage.Attachment.Offload', 'write');
        AssertEffect('Storage.Attachment.CreateLinked', 'write');
        AssertEffect('Storage.Attachment.CreateForRecord', 'write');
        AssertEffect('Storage.Upload.Begin', 'write');
        AssertEffect('Storage.Upload.Append', 'write');
        AssertEffect('Storage.Upload.Commit', 'write');
        AssertEffect('Storage.Upload.CommitToRecord', 'write');
        AssertEffect('Storage.Upload.Abort', 'write');
        AssertEffect('Storage.Attachment.Restore', 'irreversible');
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