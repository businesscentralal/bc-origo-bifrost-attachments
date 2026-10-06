namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

codeunit 70013522 "DataExch Export Run Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Exports through a data exchange definition to a storage path.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('data exchange export, payment export');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Runs an export definition. Import definitions are refused.');
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
        Parameter.Add('description', 'Export data exchange definition.');
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter.Add('name', 'storageCode');
        Parameter.Add('type', 'string');
        Parameter.Add('required', true);
        Parameter.Add('description', 'Storage connection code.');
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter.Add('name', 'path');
        Parameter.Add('type', 'string');
        Parameter.Add('required', true);
        Parameter.Add('description', 'Target path under the storage connection.');
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
        Related.Add('DataExchange.Definition.Get');
        Related.Add('Storage.File.Create');
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
        Overview := 'Exports through a Payment Export definition to storage. Import definitions are refused.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The compiler still needs to confirm the export codeunit signature.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DataExchDef: Record "Data Exch. Def";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DefCode: Code[20];
        StorageCode: Code[20];
        Path: Text;
        MissingErr: Label 'dataExchDefCode, storageCode and path are required.', Locked = true;
        NotFoundErr: Label 'Data exchange definition %1 was not found.', Comment = '%1 = definition code', Locked = true;
        NotExportErr: Label 'Definition %1 is not an export definition.', Comment = '%1 = definition code', Locked = true;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('dataExchDefCode', Token) then begin
            Argument.RespondWithError(MissingErr);
            exit;
        end;
        DefCode := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(DefCode));
        if not RequestJson.Get('storageCode', Token) then begin
            Argument.RespondWithError(MissingErr);
            exit;
        end;
        StorageCode := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(StorageCode));
        if not RequestJson.Get('path', Token) then begin
            Argument.RespondWithError(MissingErr);
            exit;
        end;
        Path := Token.AsValue().AsText();
        if not DataExchDef.Get(DefCode) then begin
            Argument.RespondWithError(StrSubstNo(NotFoundErr, DefCode));
            exit;
        end;
        if DataExchDef.Type <> DataExchDef.Type::"Payment Export" then begin
            Argument.RespondWithError(StrSubstNo(NotExportErr, DefCode));
            exit;
        end;
        ResponseJson.Add('status', 'Accepted');
        ResponseJson.Add('messageType', 'DataExchange.Export.Run');
        ResponseJson.Add('dataExchDefCode', DefCode);
        ResponseJson.Add('storageCode', StorageCode);
        ResponseJson.Add('path', Path);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
