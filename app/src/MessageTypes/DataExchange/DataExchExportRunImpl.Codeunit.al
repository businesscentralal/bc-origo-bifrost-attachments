namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>DataExchange.Export.Run</c>. Exports records with a Generic Export definition and
/// delivers the file to storage or inline.
/// </summary>
codeunit 10035164 "DataExch Export Run Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        ExportMgt: Codeunit "DataExch Export Mgt ori";
    begin
        ExportMgt.RunGenericExport(Rec);
    end;

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
        DescriptionLbl: Label 'Exports records with a Generic Export definition and writes the file to storage or returns it inline.', Comment = 'is-IS=Flytur út færslur með skilgreiningu fyrir almennan útflutning og skrifar skrána í geymslu eða skilar henni innfellt.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'data exchange export, export records to file, export csv, generic export, export to storage', Comment = 'is-IS=útflutningur gagnaskipta, flytja færslur út í skrá, flytja út csv, almennur útflutningur, flytja út í geymslu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Runs a Generic Export definition over a table view or a list of record SystemIds and delivers the file; payment files use DataExchange.PaymentExport.Run.', Locked = true;
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
        Envelope.Add('messageType', 'DataExchange.Export.Run');
        exit(true);
    end;

    /// <summary>Supplies the target chapter for this message type.</summary>
    /// <param name="Target">Out: the record the request addresses.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Target := ContractParts.GetDataExchangeTarget('DataExchange.Export.Run');
        exit(true);
    end;

    /// <summary>Supplies the parameters chapter for this message type.</summary>
    /// <param name="Parameters">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Export.Run');
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Export.Run');
        exit(true);
    end;

    /// <summary>Supplies the errors chapter for this message type.</summary>
    /// <param name="Errors">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Export.Run');
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Export.Run');
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
        Related := ContractParts.GetRelated('DataExchange.Export.Run');
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no workflow chapter.</summary>
    /// <param name="Workflow">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the recorded English examples for this message type.</summary>
    /// <param name="Examples">Out: recorded request and answer pairs.</param>
    /// <returns>True when recorded examples are available.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Examples := ContractParts.GetExamples('DataExchange.Export.Run');
        exit(Examples.Count() > 0);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview in the current language.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Selects the records of the mapping source table with tableView or recordIds, runs the standard export steps of the definition (Export Mapping and the writer) and writes the file to storage (storageCode with path or folderPath) and/or returns it inline (at most 1 MB). The Data Exch. entry keeps the file.', Comment = 'is-IS=Velur færslur upprunatöflu vörpunarinnar með tableView eða recordIds, keyrir stöðluð útflutningsskref skilgreiningarinnar (Export Mapping og ritarann) og skrifar skrána í geymslu (storageCode með path eða folderPath) og/eða skilar henni innfellt (mest 1 MB). Gagnaskiptafærslan geymir skrána.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes in the current language.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Only Generic Export definitions are accepted; import definitions are refused and payment definitions point to DataExchange.PaymentExport.Run. tableId or tableName must be the mapping table. The external data handling step of the definition is replaced by the delivery. A file over 1 MB with inline true, or a failed storage write, rolls the whole export back.', Comment = 'is-IS=Aðeins skilgreiningar fyrir almennan útflutning eru leyfðar; innflutningsskilgreiningum er hafnað og greiðsluskilgreiningar vísa á DataExchange.PaymentExport.Run. tableId eða tableName verður að vera tafla vörpunarinnar. Afhendingin kemur í stað skrefs skilgreiningarinnar fyrir ytri gagnameðhöndlun. Skrá yfir 1 MB með inline true, eða misheppnuð skrif í geymslu, afturkalla allan útflutninginn.';
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

    /// <summary>Validates the definition, the records and the delivery before writing; a later failure rolls back.</summary>
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
        Codeunit.Run(Codeunit::"DataExch Export Run Impl ori", Argument);
    end;
}
