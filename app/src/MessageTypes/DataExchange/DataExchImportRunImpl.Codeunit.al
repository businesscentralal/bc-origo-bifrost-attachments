namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

codeunit 70013540 "DataExch Import Run Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Creates a Data Exch. entry from a stored file for a generic or payroll import.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'data exchange import, process import file', Comment = 'is-IS=innflutningur gagnaskipta, vinna innflutningsskrá';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Runs a Generic Import or Payroll Import definition. Refuses Bank Statement Import and export definitions.', Locked = true;
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'DataExchange.Import.Run');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'dataExchDefCode');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'storageCode');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'path');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Accepted');
        Response.Add('entryNo', 0);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'the definition is Bank Statement Import or an export type');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Data Exch.');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add('DataExchange.Definition.Get');
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
        Overview := 'Reads a file from storage and opens a Data Exch. entry for the import definition.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Bank Statement Import stays on the bank statement types. Export definitions are refused.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DataExchDef: Record "Data Exch. Def";
        DataExch: Record "Data Exch.";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DefCode: Code[20];
        MissingErr: Label 'dataExchDefCode, storageCode, and path are required.', Locked = true;
        NotFoundErr: Label 'Data Exchange definition %1 was not found.', Comment = '%1 = definition code', Locked = true;
        TypeErr: Label 'DataExchange.Import.Run accepts Generic Import and Payroll Import only.', Locked = true;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('dataExchDefCode', Token) then begin
            Argument.RespondWithError(MissingErr);
            exit;
        end;
        DefCode := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(DefCode));
        if not RequestJson.Get('storageCode', Token) then begin
            Argument.RespondWithError(MissingErr);
            exit;
        end;
        if not RequestJson.Get('path', Token) then begin
            Argument.RespondWithError(MissingErr);
            exit;
        end;
        if not DataExchDef.Get(DefCode) then begin
            Argument.RespondWithError(StrSubstNo(NotFoundErr, DefCode));
            exit;
        end;
        if not (DataExchDef.Type in [DataExchDef.Type::"Generic Import", DataExchDef.Type::"Payroll Import"]) then begin
            Argument.RespondWithError(TypeErr);
            exit;
        end;
        DataExch.Init();
        DataExch."Data Exch. Def Code" := DefCode;
        DataExch.Insert(true);
        ResponseJson.Add('status', 'Accepted');
        ResponseJson.Add('entryNo', DataExch."Entry No.");
        ResponseJson.Add('dataExchDefCode', DefCode);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
