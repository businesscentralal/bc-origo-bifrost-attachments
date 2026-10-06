namespace Origo.Bifrost.Attachments;

using Microsoft.Bank.Setup;
using Origo.Bifrost;

codeunit 70013536 "DataExch Def Export Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        exit(DataExchDef.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch. Def");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Exports a Data Exchange definition header for reinstall.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('export data exchange definition, dump definition');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Returns the definition code, type, and name so it can be imported again.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'DataExchange.Definition.Export');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Data Exch. Def');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'code');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('code', '');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'code was not found');
        Errors.Add(ErrorJson);
        exit(true);
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
        Overview := 'Reads a data exchange definition so it can be installed in another company.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Returns the header. Line and column mapping XML is the compiler follow-up for issue 26.';
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
        DefinitionCode: Code[20];
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('code', Token) then begin
            Argument.RespondWithError('code is required.');
            exit;
        end;
        DefinitionCode := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(DefinitionCode));
        if not DataExchDef.Get(DefinitionCode) then begin
            Argument.RespondWithError('Data exchange definition ' + DefinitionCode + ' was not found.');
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('code', DataExchDef.Code);
        ResponseJson.Add('name', DataExchDef.Name);
        ResponseJson.Add('type', Format(DataExchDef.Type));
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
