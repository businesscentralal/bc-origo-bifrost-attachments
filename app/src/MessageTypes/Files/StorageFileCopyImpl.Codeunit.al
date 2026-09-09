namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.File.Copy</c> message type. Copies a file within the
/// configured storage connection.
/// </summary>
codeunit 10035648 "Storage File Copy Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        exit(StorageSetup.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Copies a file within the configured storage connection.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        FileHelp: Codeunit "Storage File Help ori";
    begin
        FileHelp.GetHelp(Enum::"Message Type ori"::"Storage.File.Copy", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        StorageSetup: Record "Storage Setup ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        RequestJson: JsonObject;
        SourcePath: Text;
        TargetPath: Text;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        RequestJson := Argument.GetRequestJson();
        if not RequestMgt.ResolveSetup(Argument, RequestJson, StorageSetup, Connector) then
            exit;
        if not RequestMgt.RequireParam(Argument, RequestJson, 'sourcePath', SourcePath) then
            exit;
        if not RequestMgt.RequireParam(Argument, RequestJson, 'targetPath', TargetPath) then
            exit;
        RequestMgt.ExecuteCopyFile(Argument, StorageSetup, Connector, SourcePath, TargetPath);
    end;
}
