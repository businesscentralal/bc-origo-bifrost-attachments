namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>DataExchange.Definition.Import</c>. Installs Data Exchange definitions from the
/// standard definition XML.
/// </summary>
codeunit 70013509 "DataExch Def Install Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        DefTransfer: Codeunit "DataExch Def Transfer ori";
    begin
        DefTransfer.ImportDefinitions(Rec);
    end;

    /// <summary>Reports whether the caller holds the table permission this message type needs.</summary>
    /// <returns>True when the permission is held.</returns>
    procedure IsEnabled(): Boolean
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        exit(DataExchDef.WritePermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch. Def");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Installs Data Exchange definitions with their lines, columns and mappings from the standard definition XML.', Comment = 'is-IS=Setur upp skilgreiningar gagnaskipta með línum, dálkum og vörpunum úr stöðluðu XML-skjali skilgreininga.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'install data exchange definition, import definition xml, load file format, copy data exchange definition, add import format', Comment = 'is-IS=setja upp skilgreiningu gagnaskipta, flytja inn XML skilgreiningar, hlaða skráarsniði, afrita skilgreiningu gagnaskipta, bæta við innflutningssniði';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Creates or replaces Data Exchange definitions from an XML file, the same file the Export Data Exchange Definition action writes and DataExchange.Definition.Export returns.', Locked = true;
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
        Envelope.Add('messageType', 'DataExchange.Definition.Import');
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
        Parameters := ContractParts.GetParameters('DataExchange.Definition.Import');
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Definition.Import');
        exit(true);
    end;

    /// <summary>Supplies the errors chapter for this message type.</summary>
    /// <param name="Errors">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Definition.Import');
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Definition.Import');
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
        Related := ContractParts.GetRelated('DataExchange.Definition.Import');
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
        OverviewLbl: Label 'Reads the XML from storageCode and path, from contentBase64 (at most 1 MB) or from a complete chunked upload (uploadId, which is consumed), and installs it with the base XMLport Imp / Exp Data Exch Def & Map. newCode installs a single definition under another code.', Comment = 'is-IS=Les XML-skjalið úr storageCode og path, úr contentBase64 (mest 1 MB) eða úr fullgerðri upphleðslu í bútum (uploadId, sem er notuð upp) og setur það upp með XMLport grunnkerfisins Imp / Exp Data Exch Def & Map. newCode setur eina skilgreiningu upp undir öðrum kóða.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes in the current language.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'An existing code is refused unless overwrite is true; overwrite deletes the existing definition with its lines and mappings first. Every code in the file is checked before anything is installed. Wire an import definition to incoming documents with DataExchange.Type.Set.', Comment = 'is-IS=Kóða sem er til er hafnað nema overwrite sé true; overwrite eyðir fyrst skilgreiningunni sem er til með línum hennar og vörpunum. Allir kóðar skrárinnar eru athugaðir áður en nokkuð er sett upp. Tengdu innflutningsskilgreiningu við innkomuskjöl með DataExchange.Type.Set.';
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

    /// <summary>Validates the source and every definition code before installing; an install error rolls back.</summary>
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
        Codeunit.Run(Codeunit::"DataExch Def Install Impl ori", Argument);
    end;
}
