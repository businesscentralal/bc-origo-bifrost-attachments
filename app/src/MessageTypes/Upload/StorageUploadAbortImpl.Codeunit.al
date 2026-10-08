namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Upload.Abort</c> message type. Discards an open upload
/// session and all of its chunks without writing anything to storage.
/// </summary>
codeunit 10035656 "Storage Upload Abort Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Discards an open upload session and all its chunks without writing to storage.', Comment = 'is-IS=Fleygir opinni upphleðslulotu og öllum hlutum hennar án þess að skrifa í geymslu.';
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
        KeywordsLbl: Label 'cancel the upload, abort upload, discard upload, stop uploading, throw away the chunks, cancel upload session', Comment = 'is-IS=hætta við upphleðslu, hætta við upphleðsluna, fleygja upphleðslu, stöðva upphleðslu, henda bútum, hætta við upphleðslulotu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Discards an open upload session and its chunks without writing anything to storage or to any record.', Comment = 'is-IS=Fleygir opinni upphleðslulotu og hlutum hennar án þess að skrifa í geymslu eða á neina færslu.';
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
        Parameters := ContractParts.GetParameters('Storage.Upload.Abort');
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.Upload.Abort');
        exit(true);
    end;

    /// <summary>Supplies the errors chapter for this message type.</summary>
    /// <param name="Errors">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.Upload.Abort');
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.Upload.Abort');
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
        Related := ContractParts.GetRelated('Storage.Upload.Abort');
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

    /// <summary>Declares that this implementation supplies no notes chapter.</summary>
    /// <param name="Notes">Out: cleared to empty.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>Inbound for the requested mutation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Asserts version 1 and licensing, then delegates deleting the open upload session and its chunks.</summary>
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
        if UploadMgt.AbortUpload(Argument, ResultData) then
            RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
