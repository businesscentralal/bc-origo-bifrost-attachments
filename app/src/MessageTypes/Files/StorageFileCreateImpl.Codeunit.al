namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.Utilities;

/// <summary>
/// Implementation of the <c>Storage.File.Create</c> message type. Uploads base64 content
/// to a file path in the configured storage connection.
/// </summary>
codeunit 10035649 "Storage File Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Uploads a base64 file of up to 240 MiB to a path in one call. For larger files, use Storage.Upload.Begin, Append and Commit.');
    end;

    /// <summary>
    /// Search terms users say for this type, English with the Icelandic translation. Used to rank
    /// search results; never shown to the caller.
    /// </summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'upload a file, save the pdf to storage, save file to cloud folder, write file to storage, put file in sharepoint, upload to blob storage, store a document in the cloud, single upload, save to cloud storage', Comment = 'is-IS=hlaða upp skrá, hlaða upp skránni, vista pdf í geymslu, vista skrá í skýjamöppu, skrifa skrá í geymslu, setja skrá í sharepoint, vista skjal í skýinu, vista skjalið í geymslu, geyma skjal í skýinu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Uploads a whole file of up to 240 MiB to a storage path in one call; use the chunked upload types for larger files or files sent in parts.', Locked = true;
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Envelope := ContractParts.GetEnvelope(true); exit(true); end;
    procedure GetTarget(var Target: JsonArray): Boolean begin exit(false); end;
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Parameters := ContractParts.GetParameters('Storage.File.Create'); exit(true); end;
    procedure GetResponse(var Response: JsonObject): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Response := ContractParts.GetResponse('Storage.File.Create'); exit(true); end;
    procedure GetErrors(var Errors: JsonArray): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Errors := ContractParts.GetErrors('Storage.File.Create'); exit(true); end;
    procedure GetEffect(var Effect: JsonObject): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Effect := ContractParts.GetEffect('Storage.File.Create'); exit(true); end;
    procedure GetMetering(var Metering: JsonObject): Boolean begin exit(false); end;
    procedure GetRelated(var Related: JsonArray): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Related := ContractParts.GetRelated('Storage.File.Create'); exit(true); end;
    procedure GetWorkflow(var Workflow: JsonObject): Boolean begin exit(false); end;
    procedure GetExamples(var Examples: JsonArray): Boolean begin exit(false); end;
    procedure GetOverview(var Overview: Text): Boolean begin exit(false); end;
    procedure GetNotes(var Notes: Text): Boolean begin exit(false); end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        FileHelp: Codeunit "Storage File Help ori";
    begin
        FileHelp.GetHelp(Enum::"Message Type ori"::"Storage.File.Create", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        StorageSetup: Record "Storage Setup ori";
        TempBlob: Codeunit "Temp Blob";
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
        Reader.ReadPath(Argument, RequestJson, 'path', true, Path);
        Reader.ReadBase64Content(Argument, RequestJson, 'contentBase64', true, TempBlob);
        if Reader.RespondIfErrors(Argument) then
            exit;
        RequestMgt.ExecuteCreateFile(Argument, StorageSetup, Connector, Path, TempBlob);
    end;
}
