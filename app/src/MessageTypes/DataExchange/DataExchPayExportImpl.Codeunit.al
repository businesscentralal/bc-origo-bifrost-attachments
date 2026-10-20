namespace Origo.Bifrost.Attachments;

using Microsoft.Finance.GeneralLedger.Journal;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>DataExchange.PaymentExport.Run</c>. Exports a payment journal batch with the
/// payment export format of its bank account and delivers the bank file to storage or inline.
/// </summary>
codeunit 10035168 "DataExch Pay Export Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        ExportMgt: Codeunit "DataExch Export Mgt ori";
    begin
        ExportMgt.RunPaymentExport(Rec);
    end;

    /// <summary>Reports whether the caller holds the table permission this message type needs.</summary>
    /// <returns>True when the permission is held.</returns>
    procedure IsEnabled(): Boolean
    var
        GenJournalLine: Record "Gen. Journal Line";
    begin
        exit(GenJournalLine.WritePermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Gen. Journal Line");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Exports a payment journal batch to a bank payment file and delivers it to storage or inline.', Comment = 'is-IS=Flytur greiðslubók út í greiðsluskrá banka og afhendir hana í geymslu eða innfellt.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'export payments, payment file, sepa credit transfer, pain.001, bank file from payment journal, export payment journal', Comment = 'is-IS=flytja út greiðslur, greiðsluskrá, SEPA-millifærsla, pain.001, bankaskrá úr greiðslubók, flytja út greiðslubók';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Runs the Payment Journal export of one journal batch (SEPA credit transfer or a Data Exchange payment export format) and puts the bank file in storage, marking the lines as exported.', Comment = 'is-IS=Keyrir útflutning einnar greiðslubókarkeyrslu (SEPA-millifærslu eða greiðsluútflutningssniðs gagnaskipta), setur bankaskrána í geymslu og merkir línurnar sem útfluttar.';
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
        Envelope := ContractParts.GetDataExchangeEnvelope(true);
        Envelope.Add('messageType', 'DataExchange.PaymentExport.Run');
        exit(true);
    end;

    /// <summary>Supplies the target chapter for this message type.</summary>
    /// <param name="Target">Out: the record the request addresses.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Target := ContractParts.GetDataExchangeTarget('DataExchange.PaymentExport.Run');
        exit(true);
    end;

    /// <summary>Supplies the parameters chapter for this message type.</summary>
    /// <param name="Parameters">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.PaymentExport.Run');
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.PaymentExport.Run');
        exit(true);
    end;

    /// <summary>Supplies the errors chapter for this message type.</summary>
    /// <param name="Errors">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.PaymentExport.Run');
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.PaymentExport.Run');
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
        Related := ContractParts.GetRelated('DataExchange.PaymentExport.Run');
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
        OverviewLbl: Label 'Runs the base-app payment export of the batch, as the Export action of the Payment Journal does: the lines get Exported to Payment File, a credit transfer register keeps the file, and the file is written to storage (storageCode with path or folderPath) and/or returned inline (at most 1 MB).', Comment = 'is-IS=Keyrir útflutning greiðslna grunnkerfisins fyrir keyrsluna eins og aðgerðin Flytja út í greiðslubókinni: línurnar fá merkið Flutt út í greiðsluskrá, millifærsluskrá geymir skrána og skráin er skrifuð í geymslu (storageCode með path eða folderPath) og/eða skilað innfellt (mest 1 MB).';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes in the current language.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'The base-app export commits its own steps, so the lines stay marked even when the later storage write fails; the file is then still on the credit transfer register. Lines already exported are exported again, as the journal action does after its confirmation. A processing codeunit that downloads the file in another way cannot be captured and is refused after the export.', Comment = 'is-IS=Útflutningur grunnkerfisins staðfestir eigin skref svo línurnar eru áfram merktar þótt síðari skrif í geymslu mistakist; skráin er þá samt í millifærsluskránni. Línur sem hafa þegar verið fluttar út eru fluttar út aftur, eins og aðgerðin í bókinni gerir eftir staðfestingu. Vinnslukóðaeiningu sem halar skránni niður á annan hátt er ekki hægt að grípa og henni er hafnað eftir útflutninginn.';
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

    /// <summary>Validates the batch and the delivery, then runs the payment export and delivers the file.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Reader: Codeunit "Storage Request Reader ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        // A non-object request is refused here, before the worker reads it with GetRequestJson.
        if not Reader.ReadMutationRequest(Argument) then begin
            Reader.RespondIfErrors(Argument);
            exit;
        end;
        // No Boolean return: an error after a write rolls back every write of the call.
        Codeunit.Run(Codeunit::"DataExch Pay Export Impl ori", Argument);
    end;
}
