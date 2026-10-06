namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

codeunit 70013523 "DataExch Def Export Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch. Def");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Exports a data exchange definition as XML.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('data exchange definition export, xml');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Returns the definition XML for one data exchange definition.');
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
        Parameter.Add('name', 'dataExchDefCode');
        Parameter.Add('type', 'string');
        Parameter.Add('required', true);
        Parameter.Add('description', 'Data exchange definition code.');
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
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add('DataExchange.Definition.Get');
        Related.Add('DataExchange.Definition.Import');
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
        Overview := 'Exports one data exchange definition. The XML body is returned as definitionXml.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The compiler still needs to confirm the definition export procedure.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DataExchDef: Record "Data Exch. Def";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DefCode: Code[20];
        MissingErr: Label 'dataExchDefCode is required.', Locked = true;
        NotFoundErr: Label 'Data exchange definition %1 was not found.', Comment = '%1 = definition code', Locked = true;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('dataExchDefCode', Token) then begin
            Argument.RespondWithError(MissingErr);
            exit;
        end;
        DefCode := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(DefCode));
        if not DataExchDef.Get(DefCode) then begin
            Argument.RespondWithError(StrSubstNo(NotFoundErr, DefCode));
            exit;
        end;
        DataExchDef.SetRecFilter();
        DataExchDef.Export(DefCode + '.xml');
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'DataExchange.Definition.Export');
        ResponseJson.Add('dataExchDefCode', DefCode);
        ResponseJson.Add('fileName', DefCode + '.xml');
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
