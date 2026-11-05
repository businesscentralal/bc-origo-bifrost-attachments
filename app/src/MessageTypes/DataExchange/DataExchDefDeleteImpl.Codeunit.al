namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Disabled message type: Data Exchange definitions are deleted in Business Central itself (#211).
/// The enum value stays so that no AppSource breaking change is made; every call is refused and deletes nothing.
/// </summary>
codeunit 10035155 "DataExch Def Delete Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports that this message type is disabled; it deletes nothing.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the table associated with this message type.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch. Def");
    end;

    /// <summary>Describes the current operation.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Disabled. Delete Data Exchange definitions in Business Central.', Comment = 'is-IS=Óvirkt. Eyddu skilgreiningum gagnaskipta í Business Central.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'delete data exchange definition', Comment = 'is-IS=eyða skilgreiningu gagnaskipta';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains when to select this message type.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Disabled; do not select. Always refused and deletes nothing. Delete Data Exchange definitions in Business Central.', Comment = 'is-IS=Óvirkt; ekki velja. Er alltaf hafnað og eyðir engu. Eyddu skilgreiningum gagnaskipta í Business Central.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the supported wire envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetDataExchangeEnvelope(true);
        Envelope.Add('messageType', 'DataExchange.Definition.Delete');
        exit(true);
    end;

    /// <summary>Reports that this operation has no envelope target.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes the accepted request keys.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Definition.Delete');
        exit(true);
    end;

    /// <summary>Describes the successful response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Definition.Delete');
        exit(true);
    end;

    /// <summary>Describes operation refusals.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Definition.Delete');
        exit(true);
    end;

    /// <summary>Describes the database effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Definition.Delete');
        exit(true);
    end;

    /// <summary>Reports that this operation adds no custom metering chapter.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Lists related message types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Get', 'Read a definition.'));
        Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', 'Find a definition code.'));
        exit(true);
    end;

    /// <summary>Reports that no custom workflow chapter is supplied.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        exit(Guide.GetWorkflow('DataExchange.Definition.Delete', Workflow));
    end;

    /// <summary>Reports that no example chapter is supplied.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        Examples := ContractParts.GetExamples('DataExchange.Definition.Delete');
        Guide.PrependSuccessExample('DataExchange.Definition.Delete', Examples);
        exit(Examples.Count() > 0);
    end;

    /// <summary>Summarizes the operation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Disabled. DataExchange.Definition.Delete is refused with PreconditionFailed and deletes nothing. Delete Data Exchange definitions in Business Central.', Locked = true;
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains operation restrictions.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Disabled since 05.11.2026 (#211): the platform does not provide message types that delete definitions. The message type stays registered so that existing callers get a typed refusal instead of an unknown-type error. Delete Data Exchange definitions in Business Central, or delete entries with DataExchange.Entry.Delete.', Locked = true;
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Refuses every call with a typed error; no definition is read or deleted.</summary>
    /// <param name="Argument">The licensed request and response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Reader: Codeunit "Storage Request Reader ori";
        DisabledErr: Label 'DataExchange.Definition.Delete is disabled. Delete Data Exchange Definitions in Business Central.', Comment = 'is-IS=DataExchange.Definition.Delete er óvirkt. Eyddu skilgreiningum gagnaskipta í Business Central.';
        DisabledExpectedLbl: Label 'a message type that is enabled; DataExchange.Definition.Delete is disabled', Comment = 'is-IS=virk skilaboðagerð; DataExchange.Definition.Delete er óvirk';
        DisabledNextStepLbl: Label 'Delete the Data Exchange definition in Business Central (page Data Exchange Definitions). Use DataExchange.Entry.Delete to delete entries.', Comment = 'is-IS=Eyddu skilgreiningu gagnaskipta í Business Central (síðan Skilgreiningar gagnaskipta). Notaðu DataExchange.Entry.Delete til að eyða færslum.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, DisabledErr, 'type', 'DataExchange.Definition.Delete', DisabledExpectedLbl, DisabledNextStepLbl);
        Reader.RespondIfErrors(Argument);
    end;
}
