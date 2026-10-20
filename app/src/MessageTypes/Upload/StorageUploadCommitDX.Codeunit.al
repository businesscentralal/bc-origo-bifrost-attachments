namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>Storage.Upload.CommitToDataExchange</c>. Assembles a chunked upload into a
/// Data Exch. entry, parses it with an import definition and optionally applies the mappings.
/// </summary>
codeunit 10035187 "Storage Upload Commit DX ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permission this message type needs.</summary>
    /// <returns>True when the permission is held.</returns>
    procedure IsEnabled(): Boolean
    var
        DataExch: Record "Data Exch.";
    begin
        exit(DataExch.WritePermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch.");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Assembles uploaded chunks into a Data Exch. entry and parses the file with an import definition.', Comment = 'is-IS=Sameinar upphlaðna búta í gagnaskiptafærslu og þáttar skrána með innflutningsskilgreiningu.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'import large file into data exchange, upload csv to data exchange, finish upload as data exchange import, parse uploaded file, chunked import', Comment = 'is-IS=flytja stóra skrá inn í gagnaskipti, hlaða csv-skrá upp í gagnaskipti, staðfesta upphleðslu sem innflutning gagnaskipta, þátta upphlaðna skrá, innflutningur í bútum';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Turns a complete chunked upload into a parsed Data Exch. entry of a Generic Import or Payroll Import definition, instead of a file in storage or an attachment.', Comment = 'is-IS=Breytir fullbúinni upphleðslu í bútum í þáttaða gagnaskiptafærslu samkvæmt skilgreiningu fyrir almennan innflutning eða launainnflutning, í stað skrár í geymslu eða viðhengis.';
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
        Envelope.Add('messageType', 'Storage.Upload.CommitToDataExchange');
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
    /// <param name="Parameters">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Storage.Upload.CommitToDataExchange');
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.Upload.CommitToDataExchange');
        exit(true);
    end;

    /// <summary>Supplies the errors chapter for this message type.</summary>
    /// <param name="Errors">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.Upload.CommitToDataExchange');
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.Upload.CommitToDataExchange');
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
        Related := ContractParts.GetRelated('Storage.Upload.CommitToDataExchange');
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

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview in the current language.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Assembles the chunks of an open upload session, inserts a Data Exch. entry with the file and runs the definition reader. The session is committed. With keepFileInStorage the file is also written to the session path; with process the mappings run after the import is committed.', Comment = 'is-IS=Sameinar búta opinnar upphleðslulotu, stofnar gagnaskiptafærslu með skránni og keyrir lesara skilgreiningarinnar. Lotan er staðfest. Með keepFileInStorage er skráin líka skrifuð á slóð lotunnar; með process eru varpanirnar keyrðar eftir að innflutningurinn er staðfestur.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes in the current language.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'A file the reader cannot read answers an error and leaves the session open with its chunks, so the upload can be retried. keepFileInStorage needs a session that was begun with a storageCode. Bank Statement Import and export definitions are refused.', Comment = 'is-IS=Skrá sem lesarinn getur ekki lesið skilar villu og lotan er áfram opin með bútunum svo reyna megi aftur. keepFileInStorage krefst lotu sem var hafin með storageCode. Skilgreiningum fyrir innflutning bankayfirlita og útflutningi er hafnað.';
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

    /// <summary>Asserts version 1 and licensing, then commits the upload into a Data Exch. entry.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        UploadMgt: Codeunit "Storage Upload Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ResultData: JsonObject;
    begin
        // Every problem of the request and the session is answered before the first write.
        // A reader or storage failure after a write is raised, so every write rolls back.
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if UploadMgt.CommitToDataExchange(Argument, ResultData) then
            RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
