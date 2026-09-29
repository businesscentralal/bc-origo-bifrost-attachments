namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.ExternalFileStorage;

/// <summary>
/// Implementation of the <c>Storage.File.List</c> message type. Lists the files in a
/// directory of the configured storage connection.
/// </summary>
codeunit 10035653 "Storage File List Impl ori" implements "Msg Interface ori", "Msg Discovery ori"
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
        exit('Lists the files in a directory of the configured storage connection.');
    end;

    /// <summary>
    /// Search terms users say for this type, English with the Icelandic translation. Used to rank
    /// search results; never shown to the caller.
    /// </summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'list files in folder, files in the folder, what files are in storage, show folder contents, browse cloud folder, files in the container, list blobs, list stored documents', Comment = 'is-IS=skrár í möppu, skrárnar í möppunni, hvaða skrár eru í geymslu, sýna innihald möppu, skoða skýjamöppu, lista skrár, listi yfir skrár, skrár í geymslu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Lists the files in one folder of a storage connection; use the directory listing type instead to see its subfolders.', Locked = true;
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        FileHelp: Codeunit "Storage File Help ori";
    begin
        FileHelp.GetHelp(Enum::"Message Type ori"::"Storage.File.List", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        StorageSetup: Record "Storage Setup ori";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        RequestJson: JsonObject;
        Path: Text;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        RequestJson := Argument.GetRequestJson();
        RequestMgt.ReadSetup(Argument, RequestJson, StorageSetup, Connector);
        Reader.ReadPath(Argument, RequestJson, 'path', false, Path);
        if Reader.RespondIfErrors(Argument) then
            exit;
        RequestMgt.ExecuteList(Argument, StorageSetup, Connector, Path, Enum::"Ext. File Storage File Type"::File);
    end;
}
