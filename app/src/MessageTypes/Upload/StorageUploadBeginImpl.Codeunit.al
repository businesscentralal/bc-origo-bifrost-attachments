namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Upload.Begin</c> message type. Opens a chunked upload
/// session and returns the <c>uploadId</c> used to append chunks and commit the file.
/// </summary>
codeunit 10035658 "Storage Upload Begin Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Opens a chunked upload session for a file larger than one call can carry, sent as chunks of up to 240 MiB each.');
    end;

    /// <summary>
    /// Search terms users say for this type, English with the Icelandic translation. Used to rank
    /// search results; never shown to the caller.
    /// </summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'start a large upload, upload a big file, chunked upload, upload in parts, stream a file, resumable upload, start upload session, file too large for one call', Comment = 'is-IS=hefja stóra upphleðslu, hlaða upp stórri skrá, upphleðsla í hlutum, hlaða upp í bútum, streyma skrá, hefja upphleðslulotu, skrá of stór fyrir eitt kall';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Opens a chunked upload session for files over 240 MiB or streamed in parts; use the single-call file create for anything that fits in one request.', Locked = true;
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(true);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Storage.Upload.Begin');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.Upload.Begin');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.Upload.Begin');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.Upload.Begin');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('Storage.Upload.Begin');
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        exit(false);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The default root is bifrost-uploads/. fileName must be a file name without folders; use path or folderPath for directories.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        UploadMgt: Codeunit "Storage Upload Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ResultData: JsonObject;
    begin
        // Every problem the request or the data can show is answered before the first write.
        // A failure after a write (for example the storage upload) is raised, so the write rolls back.
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if UploadMgt.BeginUpload(Argument, ResultData) then
            RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
