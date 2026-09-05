namespace Origo.Bifrost.Hnitbjorg;

using Origo.Bifrost;
using System.ExternalFileStorage;

/// <summary>
/// Implementation of the <c>Storage.Account.List</c> message type. Lists the configured
/// storage connections — their codes, descriptions, connectors and enabled state — so a
/// caller can discover the <c>storageCode</c> values to use. No secrets are exposed.
/// </summary>
codeunit 10035639 "Storage Account List Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    internal procedure IsEnabled(): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        exit(StorageSetup.ReadPermission());
    end;

    internal procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    internal procedure GetDescription(): Text[250]
    begin
        exit('Lists the configured storage connections (codes, descriptions, connectors and enabled state). No secrets are exposed.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        AccountHelp: Codeunit "Storage Account Help ori";
    begin
        AccountHelp.GetHelp(Enum::"Message Type ori"::"Storage.Account.List", Argument);
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        StorageSetup: Record "Storage Setup ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        DataObject: JsonObject;
        AccountsArray: JsonArray;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        StorageSetup.SetLoadFields("Code", Description, Connector, "Base Path", Enabled);
        if StorageSetup.FindSet() then
            repeat
                AccountsArray.Add(AccountToJson(StorageSetup));
            until StorageSetup.Next() = 0;
        DataObject.Add('accounts', AccountsArray);
        RequestMgt.RespondSuccess(Argument, DataObject);
    end;

    local procedure AccountToJson(var StorageSetup: Record "Storage Setup ori") AccountObject: JsonObject
    begin
        AccountObject.Add('code', StorageSetup."Code");
        AccountObject.Add('description', StorageSetup.Description);
        AccountObject.Add('connector', ConnectorName(StorageSetup.Connector));
        AccountObject.Add('basePath', StorageSetup."Base Path");
        AccountObject.Add('enabled', StorageSetup.Enabled);
    end;

    local procedure ConnectorName(Connector: Enum "Ext. File Storage Connector"): Text
    var
        Ordinals: List of [Integer];
        Names: List of [Text];
        Index: Integer;
    begin
        Ordinals := Connector.Ordinals();
        Names := Connector.Names();
        Index := Ordinals.IndexOf(Connector.AsInteger());
        if Index = 0 then
            exit('');
        exit(Names.Get(Index));
    end;
}
