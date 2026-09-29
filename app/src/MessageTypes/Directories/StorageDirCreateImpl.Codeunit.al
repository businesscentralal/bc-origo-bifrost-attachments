namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Directory.Create</c> message type. Creates a directory
/// in the configured storage connection.
/// </summary>
codeunit 10035644 "Storage Dir Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Creates a directory in the configured storage connection.');
    end;

    /// <summary>
    /// Search terms users say for this type, English with the Icelandic translation. Used to rank
    /// search results; never shown to the caller.
    /// </summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'create a folder, new folder, make a directory, add folder in storage, create sharepoint folder, new directory in cloud storage', Comment = 'is-IS=búa til möppu, stofna möppu, ný mappa, nýja möppu, bæta við möppu í geymslu, búa til sharepoint möppu, stofna möppu í skýinu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Creates one empty folder at a path in a storage connection; it writes no files.', Locked = true;
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Envelope := ContractParts.GetEnvelope(true); exit(true); end;
    procedure GetTarget(var Target: JsonArray): Boolean begin exit(false); end;
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Parameters := ContractParts.GetParameters('Storage.Directory.Create'); exit(true); end;
    procedure GetResponse(var Response: JsonObject): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Response := ContractParts.GetResponse('Storage.Directory.Create'); exit(true); end;
    procedure GetErrors(var Errors: JsonArray): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Errors := ContractParts.GetErrors('Storage.Directory.Create'); exit(true); end;
    procedure GetEffect(var Effect: JsonObject): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Effect := ContractParts.GetEffect('Storage.Directory.Create'); exit(true); end;
    procedure GetMetering(var Metering: JsonObject): Boolean begin exit(false); end;
    procedure GetRelated(var Related: JsonArray): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Related := ContractParts.GetRelated('Storage.Directory.Create'); exit(true); end;
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
        DirHelp: Codeunit "Storage Dir Help ori";
    begin
        DirHelp.GetHelp(Enum::"Message Type ori"::"Storage.Directory.Create", Argument);
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
        Reader.ReadPath(Argument, RequestJson, 'path', true, Path);
        if Reader.RespondIfErrors(Argument) then
            exit;
        RequestMgt.ExecuteCreateDirectory(Argument, StorageSetup, Connector, Path);
    end;
}
