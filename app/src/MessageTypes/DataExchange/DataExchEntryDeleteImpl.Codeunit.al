namespace Origo.Bifrost.Attachments;

using Microsoft.EServices.EDocument;
using Origo.Bifrost;
using System.IO;

codeunit 70013544 "DataExch Entry Del Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch.");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Deletes a Data Exch. entry that is not referenced by an incoming document.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('data exchange delete, entry delete');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Deletes a Data Exch. entry and its fields.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

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

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add('DataExchange.Import.Run');
        Related.Add('DataExchange.Entry.Get');
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
        Overview := 'Deletes a Data Exch. entry. Refuses an entry referenced by an incoming document.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DataExch: Record "Data Exch.";
        DataExchField: Record "Data Exch. Field";
        IncomingDocument: Record "Incoming Document";
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
        IncomingDocument.SetRange("Data Exchange Entry No.", EntryNo);
        if not IncomingDocument.IsEmpty() then begin
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
}
