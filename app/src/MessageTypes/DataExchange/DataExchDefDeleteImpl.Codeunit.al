namespace Origo.Bifrost.Attachments;

using Microsoft.Bank.Setup;
using Origo.Bifrost;
using System.IO;

codeunit 70013543 "DataExch Def Delete Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        exit(DataExchDef.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch. Def");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Deletes a Data Exchange definition that is not referenced.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'delete data exchange definition', Comment = 'is-IS=eyða skilgreiningu gagnaskipta';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Deletes a definition. Refuses a definition used by a Data Exchange Type or Bank Export/Import Setup.', Locked = true;
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'DataExchange.Definition.Delete');
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
        ParameterJson.Add('name', 'code');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidOperation');
        ErrorJson.Add('when', 'a Data Exchange Type or bank setup references the definition');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('deletes', 'Data Exch. Def');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add('DataExchange.Definition.Get');
        Related.Add('DataExchange.Type.List');
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
        Overview := 'Deletes one Data Exchange definition after checking references.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Does not delete a definition that a Data Exchange Type or Bank Export/Import Setup still uses.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DataExchDef: Record "Data Exch. Def";
        DataExchType: Record "Data Exchange Type";
        BankExportImportSetup: Record "Bank Export/Import Setup";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DefCode: Code[20];
        MissingErr: Label 'code is required.', Locked = true;
        NotFoundErr: Label 'Data Exchange definition %1 was not found.', Comment = '%1 = definition code', Locked = true;
        UsedErr: Label 'Data Exchange definition %1 is referenced and cannot be deleted.', Comment = '%1 = definition code', Locked = true;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('code', Token) then begin
            Argument.RespondWithError(MissingErr);
            exit;
        end;
        DefCode := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(DefCode));
        if not DataExchDef.Get(DefCode) then begin
            Argument.RespondWithError(StrSubstNo(NotFoundErr, DefCode));
            exit;
        end;
        DataExchType.SetRange("Data Exch. Def. Code", DefCode);
        if not DataExchType.IsEmpty() then begin
            Argument.RespondWithError(StrSubstNo(UsedErr, DefCode));
            exit;
        end;
        BankExportImportSetup.SetRange("Data Exch. Def. Code", DefCode);
        if not BankExportImportSetup.IsEmpty() then begin
            Argument.RespondWithError(StrSubstNo(UsedErr, DefCode));
            exit;
        end;
        DataExchDef.Delete(true);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('code', DefCode);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
