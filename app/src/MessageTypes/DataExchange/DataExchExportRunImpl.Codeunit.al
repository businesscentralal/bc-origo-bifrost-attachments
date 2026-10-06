namespace Origo.Bifrost.Attachments;

using Microsoft.Bank.Setup;
using Origo.Bifrost;
using System.IO;

codeunit 70013534 "DataExch Export Run Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DataExch: Record "Data Exch.";
    begin
        exit(DataExch.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch.");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Exports through a Data Exchange definition to a named file.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('data exchange export, payment export, export file');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Runs an export definition and returns the file name.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'DataExchange.Export.Run');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Data Exch.');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'dataExchDefCode');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'fileName');
        ParameterJson.Add('type', 'text');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('fileName', '');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'the definition is not an export definition');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Data Exch.');
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
        Related.Add('Storage.File.Write');
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
        Overview := 'Creates a Data Exch. entry for an export definition and returns the target file name.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Payment export uses the same type when the definition type is Payment Export. The compiler pass must bind the export stream to storage.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DataExch: Record "Data Exch.";
        DataExchDef: Record "Data Exch. Def";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DefinitionCode: Code[20];
        FileName: Text;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('dataExchDefCode', Token) then begin
            Argument.RespondWithError('dataExchDefCode is required.');
            exit;
        end;
        DefinitionCode := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(DefinitionCode));
        if not RequestJson.Get('fileName', Token) then begin
            Argument.RespondWithError('fileName is required.');
            exit;
        end;
        FileName := Token.AsValue().AsText();
        if not DataExchDef.Get(DefinitionCode) then begin
            Argument.RespondWithError('Data exchange definition ' + DefinitionCode + ' was not found.');
            exit;
        end;
        if DataExchDef.Type = DataExchDef.Type::"Generic Import" then begin
            Argument.RespondWithError('definition must be an export definition');
            exit;
        end;

        DataExch.Init();
        DataExch."Data Exch. Def Code" := DefinitionCode;
        DataExch."File Name" := CopyStr(FileName, 1, MaxStrLen(DataExch."File Name"));
        DataExch.Insert(true);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', DataExch."Entry No.");
        ResponseJson.Add('fileName', FileName);
        ResponseJson.Add('dataExchDefCode', DefinitionCode);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
