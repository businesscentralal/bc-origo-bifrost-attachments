namespace Origo.Bifrost.Attachments;

using Microsoft.EServices.EDocument;
using Origo.Bifrost;
using System.IO;

/// <summary>Deletes unreferenced data exchange entries while preserving incoming-document relationships.</summary>
codeunit 70013544 "DataExch Entry Del Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports availability of this message implementation.</summary>
    /// <returns>The message metadata value.</returns>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the table targeted by this message.</summary>
    /// <returns>The message metadata value.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch.");
    end;

    /// <summary>Returns the message description.</summary>
    /// <returns>The message metadata value.</returns>
    procedure GetDescription(): Text[250]
    begin
        exit('Deletes a Data Exch. entry that is not referenced by an incoming document.');
    end;

    /// <summary>Returns discovery keywords for the message.</summary>
    /// <returns>The message metadata value.</returns>
    procedure GetKeywords(): Text
    begin
        exit('data exchange delete, entry delete');
    end;

    /// <summary>Returns the selection guidance for the message.</summary>
    /// <returns>The message metadata value.</returns>
    procedure GetSelectionDescription(): Text
    begin
        exit('Deletes a Data Exch. entry and its fields.');
    end;

    /// <summary>Describes the supported message version and request content.</summary>
    /// <param name="Envelope">The envelope contract chapter to populate.</param>
    /// <returns>True when this contract chapter is provided.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Reports whether the message has a separate target contract.</summary>
    /// <param name="Target">The target contract chapter to populate.</param>
    /// <returns>True when this contract chapter is provided.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes the required request parameter.</summary>
    /// <param name="Parameters">The parameters contract chapter to populate.</param>
    /// <returns>True when this contract chapter is provided.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parameter: JsonObject;
    begin
        Parameter.Add('name', 'entryNo');
        Parameter.Add('type', 'integer');
        Parameter.Add('required', true);
        Parameter.Add('description', 'Data Exch. entry number.');
        Parameters.Add(Parameter);
        exit(true);
    end;

    /// <summary>Describes the response content type.</summary>
    /// <param name="Response">The response contract chapter to populate.</param>
    /// <returns>True when this contract chapter is provided.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Reports whether the message publishes an error contract chapter.</summary>
    /// <param name="Errors">The errors contract chapter to populate.</param>
    /// <returns>True when this contract chapter is provided.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes the write effects of this message.</summary>
    /// <param name="Effect">The effect contract chapter to populate.</param>
    /// <returns>True when this contract chapter is provided.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        exit(true);
    end;

    /// <summary>Reports whether the message publishes a metering contract chapter.</summary>
    /// <param name="Metering">The metering contract chapter to populate.</param>
    /// <returns>True when this contract chapter is provided.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Lists related data exchange messages.</summary>
    /// <param name="Related">The related contract chapter to populate.</param>
    /// <returns>True when this contract chapter is provided.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add('DataExchange.Import.Run');
        Related.Add('DataExchange.Entry.Get');
        exit(true);
    end;

    /// <summary>Reports whether the message publishes a workflow contract chapter.</summary>
    /// <param name="Workflow">The workflow contract chapter to populate.</param>
    /// <returns>True when this contract chapter is provided.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Reports whether the message publishes example requests.</summary>
    /// <param name="Examples">The examples contract chapter to populate.</param>
    /// <returns>True when this contract chapter is provided.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes the message operation.</summary>
    /// <param name="Overview">The overview contract chapter to populate.</param>
    /// <returns>True when this contract chapter is provided.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Deletes a Data Exch. entry. Refuses an entry referenced by an incoming document.';
        exit(true);
    end;

    /// <summary>Reports the available operation notes.</summary>
    /// <param name="Notes">The notes contract chapter to populate.</param>
    /// <returns>True when this contract chapter is provided.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the inbound direction of this write message.</summary>
    /// <returns>The message metadata value.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the licensed request and performs the data exchange operation.</summary>
    /// <param name="Argument">The message argument containing request and response data.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DataExch: Record "Data Exch.";
        DataExchField: Record "Data Exch. Field";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        EntryNo: Integer;
        MissingEntryErr: Label 'entryNo is required.', Locked = true;
        NotFoundErr: Label 'Data Exch. entry %1 was not found.', Comment = '%1 = entry no.', Locked = true;
        ReferencedErr: Label 'Data Exch. entry %1 is referenced by an incoming document.', Comment = '%1 = entry no.', Locked = true;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('entryNo', Token) then begin
            Argument.RespondWithError(MissingEntryErr);
            exit;
        end;
        EntryNo := Token.AsValue().AsInteger();
        if not DataExch.Get(EntryNo) then begin
            Argument.RespondWithError(StrSubstNo(NotFoundErr, EntryNo));
            exit;
        end;
        if IsReferencedByIncomingDocument(DataExch) then begin
            Argument.RespondWithError(StrSubstNo(ReferencedErr, EntryNo));
            exit;
        end;
        DataExchField.SetRange("Data Exch. No.", EntryNo);
        DataExchField.DeleteAll(true);
        DataExch.Delete(true);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'DataExchange.Entry.Delete');
        ResponseJson.Add('entryNo', EntryNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure IsReferencedByIncomingDocument(DataExch: Record "Data Exch."): Boolean
    var
        EmptyRecordId: RecordId;
    begin
        // A stale incoming-document pointer still represents a protected relationship.
        if DataExch."Incoming Entry No." <> 0 then
            exit(true);
        if DataExch."Related Record" = EmptyRecordId then
            exit(false);
        exit(DataExch."Related Record".TableNo() = Database::"Incoming Document");
    end;

}
