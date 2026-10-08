namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Upload.Begin</c> message type. Opens a chunked upload
/// session and returns the <c>uploadId</c> used to append chunks and commit the file.
/// </summary>
codeunit 10035658 "Storage Upload Begin Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports the permissions used to expose this message type; execution performs its own validation.</summary>
    /// <returns>True when the caller can read storage setup.</returns>
    procedure IsEnabled(): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        exit(StorageSetup.ReadPermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>Zero because this message does not bind a filter table.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description label in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Opens a chunked upload session for a file larger than one call can carry, sent as chunks of up to 240 MiB each.', Comment = 'is-IS=Opnar upphleðslulotu fyrir skrá sem rúmast ekki í einu kalli; hún er send í hlutum sem eru allt að 240 MiB hver.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>
    /// Search terms users say for this type, English with the Icelandic translation. Used to rank
    /// search results; never shown to the caller.
    /// </summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'start a large upload, upload a big file, chunked upload, upload in parts, stream a file, resumable upload, start upload session, file too large for one call', Comment = 'is-IS=hefja stóra upphleðslu, hlaða upp stórri skrá, upphleðsla í hlutum, hlaða upp í bútum, streyma skrá, upphleðsla sem má halda áfram, hefja upphleðslulotu, skrá of stór fyrir eitt kall';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Opens a chunked upload session for files over 240 MiB or streamed in parts; use the single-call file create for anything that fits in one request.', Comment = 'is-IS=Opnar upphleðslulotu fyrir skrár yfir 240 MiB eða skrár sendar í hlutum; notaðu skráarstofnun í einu kalli fyrir skrár sem rúmast í einni beiðni.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Supplies the envelope chapter for this message type.</summary>
    /// <param name="Envelope">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(true);
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no target chapter.</summary>
    /// <param name="Target">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the parameters chapter for this message type.</summary>
    /// <param name="Parameters">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Storage.Upload.Begin');
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.Upload.Begin');
        exit(true);
    end;

    /// <summary>Supplies the errors chapter for this message type.</summary>
    /// <param name="Errors">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.Upload.Begin');
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.Upload.Begin');
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no metering chapter.</summary>
    /// <param name="Metering">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the related chapter for this message type.</summary>
    /// <param name="Related">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('Storage.Upload.Begin');
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no workflow chapter.</summary>
    /// <param name="Workflow">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares that this implementation supplies no examples chapter.</summary>
    /// <param name="Examples">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares that this implementation supplies no overview chapter.</summary>
    /// <param name="Overview">Out: cleared to empty.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        exit(false);
    end;

    /// <summary>Supplies the notes chapter for this message type.</summary>
    /// <param name="Notes">Out: operation notes about the upload root and file-name/directory parameters.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The default root is bifrost-uploads/. fileName must be a file name without folders; use path or folderPath for directories.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>Inbound for the requested mutation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Asserts version 1 and licensing, then delegates opening an upload session.</summary>
    /// <param name="Argument">In: request and message context. Out: success response when the manager succeeds; otherwise the manager supplies the error response. Raised failures propagate to the caller.</param>
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
