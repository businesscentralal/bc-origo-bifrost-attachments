namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.ExternalFileStorage;

/// <summary>
/// Implementation of the <c>Storage.Directory.List</c> message type. Lists the
/// subdirectories of a directory in the configured storage connection.
/// </summary>
codeunit 10035647 "Storage Dir List Impl ori" implements "Msg Interface ori"
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
        exit('Lists the subdirectories of a directory in the configured storage connection.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        DirHelp: Codeunit "Storage Dir Help ori";
    begin
        DirHelp.GetHelp(Enum::"Message Type ori"::"Storage.Directory.List", Argument);
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
        Path := RequestMgt.GetText(RequestJson, 'path');
        RequestMgt.ExecuteList(Argument, StorageSetup, Connector, Path, Enum::"Ext. File Storage File Type"::Directory);
    end;
}
