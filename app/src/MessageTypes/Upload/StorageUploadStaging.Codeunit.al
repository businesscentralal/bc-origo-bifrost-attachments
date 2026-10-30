namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Assembles a chunked upload into a Foundation staging row through its public façade.
/// </summary>
codeunit 10035200 "Storage Upload Staging ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether upload sessions can be committed by this caller.</summary>
    /// <returns>True when upload sessions can be written; Foundation grants staging access inherently.</returns>
    procedure IsEnabled(): Boolean
    var
        Session: Record "Storage Upload Session ori";
    begin
        exit(Session.WritePermission());
    end;

    /// <summary>Identifies the upload session table for message filtering.</summary>
    /// <returns>The upload session table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Storage Upload Session ori");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Assembles uploaded chunks into a Foundation staging row and returns its stagingId.', Comment = 'is-IS=Sameinar upphlaðna búta í bráðabirgðafærslu í Bifröst-grunni og skilar stagingId hennar.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'stage upload, chunked binary upload, staging id, hand off large file', Comment = 'is-IS=geyma upphleðslu tímabundið, tvíundarupphleðsla í bútum, bráðabirgðaauðkenni, afhenda stóra skrá';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Hands a complete upload to a consuming message type by stagingId without external storage or an attachment.', Comment = 'is-IS=Afhendir fullbúna upphleðslu til móttökugerðar með stagingId án ytri geymslu eða viðhengis.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Supplies the envelope chapter for this message type.</summary>
    /// <param name="Envelope">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(true);
        Envelope.Add('messageType', 'Storage.Upload.CommitToStaging');
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no target chapter.</summary>
    /// <param name="Target">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        exit(Guide.GetTarget('Storage.Upload.CommitToStaging', Target));
    end;

    /// <summary>Supplies the parameters chapter for this message type.</summary>
    /// <param name="Parameters">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Storage.Upload.CommitToStaging');
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.Upload.CommitToStaging');
        exit(true);
    end;

    /// <summary>Supplies the errors chapter for this message type.</summary>
    /// <param name="Errors">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.Upload.CommitToStaging');
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.Upload.CommitToStaging');
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
    /// <param name="Related">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('Storage.Upload.CommitToStaging');
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no workflow chapter.</summary>
    /// <param name="Workflow">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        exit(Guide.GetWorkflow('Storage.Upload.CommitToStaging', Workflow));
    end;

    /// <summary>Returns the recorded English examples for this message type.</summary>
    /// <param name="Examples">Out: recorded request and answer pairs.</param>
    /// <returns>True when recorded examples are available.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        Examples := ContractParts.GetExamples('Storage.Upload.CommitToStaging');
        Guide.PrependSuccessExample('Storage.Upload.CommitToStaging', Examples);
        exit(Examples.Count() > 0);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview in the current language.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Assembles an open upload into one Foundation staging row. Returns stagingId and size, commits the session and releases its chunks. No storage connection is required.', Comment = 'is-IS=Sameinar opna upphleðslu í eina bráðabirgðafærslu í Bifröst-grunni. Skilar stagingId og size, staðfestir lotuna og losar bútana. Engin geymslutenging er nauðsynleg.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes in the current language.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Pass stagingId to a consuming message type as the same user in the same company. Take consumes the row; unconsumed rows follow Foundation retention. Foreign ids are indistinguishable from unknown ids. A failed commit rolls back every write and preserves the open session and chunks for retry.', Comment = 'is-IS=Sendu stagingId til móttökugerðar sem sami notandi í sama fyrirtæki. Take eyðir færslunni við móttöku; ónotaðar færslur fylgja varðveislureglum Bifröst-grunns. Auðkenni annarra notenda eru óaðgreinanleg frá óþekktum auðkennum. Misheppnuð staðfesting afturkallar allar skrifanir og varðveitir opna lotu og búta fyrir endurtekningu.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Asserts version 1 and licensing, then stages the complete upload.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        UploadMgt: Codeunit "Storage Upload Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ResultData: JsonObject;
    begin
        // Every problem of the request and the session is answered before the first write.
        // A staging failure is raised, so every write rolls back.
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if UploadMgt.CommitToStaging(Argument, ResultData) then
            RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
