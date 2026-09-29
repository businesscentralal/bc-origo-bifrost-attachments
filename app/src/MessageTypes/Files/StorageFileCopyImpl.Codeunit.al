namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.File.Copy</c> message type. Copies a file within the
/// configured storage connection.
/// </summary>
codeunit 10035648 "Storage File Copy Impl ori" implements "Msg Interface ori", "Msg Discovery ori"
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

    /// <summary>
    /// Search terms users say for this type, English with the Icelandic translation. Used to rank
    /// search results; never shown to the caller.
    /// </summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'copy the file, duplicate a file in storage, copy to another folder, make a copy of the document, copy blob, keep a backup copy', Comment = 'is-IS=afrita skrá, afrita skrána, tvöfalda skrá í geymslu, afrita í aðra möppu, gera afrit af skjali, afrit af skjalinu, halda afriti';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Copies a file to another path within the same storage connection and keeps the original; use the move type to relocate it instead.', Locked = true;
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
        FileHelp.GetHelp(Enum::"Message Type ori"::"Storage.File.Copy", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        StorageSetup: Record "Storage Setup ori";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        RequestJson: JsonObject;
        SourcePath: Text;
        TargetPath: Text;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        RequestJson := Argument.GetRequestJson();
        RequestMgt.ReadSetup(Argument, RequestJson, StorageSetup, Connector);
        Reader.ReadPath(Argument, RequestJson, 'sourcePath', true, SourcePath);
        Reader.ReadPath(Argument, RequestJson, 'targetPath', true, TargetPath);
        if Reader.RespondIfErrors(Argument) then
            exit;
        RequestMgt.ExecuteCopyFile(Argument, StorageSetup, Connector, SourcePath, TargetPath);
    end;
}
