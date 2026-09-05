namespace Origo.Bifrost.Hnitbjorg;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.File.Delete</c> message type. Deletes a file from the
/// configured storage connection.
/// </summary>
codeunit 10035650 "Storage File Delete Impl ori" implements "Msg Interface ori"
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
        exit('Deletes a file from the configured storage connection.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        FileHelp: Codeunit "Storage File Help ori";
    begin
        FileHelp.GetHelp(Enum::"Message Type ori"::"Storage.File.Delete", Argument);
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        StorageSetup: Record "Storage Setup ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        RequestJson: JsonObject;
        Path: Text;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        RequestJson := Argument.GetRequestJson();
        if not RequestMgt.ResolveSetup(Argument, RequestJson, StorageSetup, Connector) then
            exit;
        if not RequestMgt.RequireParam(Argument, RequestJson, 'path', Path) then
            exit;
        RequestMgt.ExecuteDeleteFile(Argument, StorageSetup, Connector, Path);
    end;
}
