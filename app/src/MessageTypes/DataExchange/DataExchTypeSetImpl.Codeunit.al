namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>Binds an existing import definition to a Data Exchange Type.</summary>
codeunit 70013531 "DataExch Type Set Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the current user has the table permission required by this message.</summary>
    procedure IsEnabled(): Boolean
    var
        DataExchangeType: Record "Data Exchange Type";
    begin
        exit(DataExchangeType.WritePermission());
    end;

    /// <summary>Returns the Microsoft table used to filter this message type.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exchange Type");
    end;

    /// <summary>Describes the existing message operation.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Creates or updates a Data Exchange Type and requires an import definition.');
    end;

    /// <summary>Returns the discovery terms for this message type.</summary>
    procedure GetKeywords(): Text
    begin
        exit('data exchange type, incoming document type, set definition');
    end;

    /// <summary>Describes when to select this message type.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit('Wires a Data Exchange Type to an import definition.');
    end;

    /// <summary>Declares the existing message name and supported version.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'DataExchange.Type.Set');
        Envelope.Add('version', 1);
        exit(true);
    end;

    /// <summary>Declares the Microsoft table targeted by this message.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Data Exchange Type');
        Target.Add(TargetJson);
        exit(true);
    end;

    /// <summary>Declares the request parameters consumed by this message.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Type.Set');
        exit(true);
    end;

    /// <summary>Describes the existing response fields.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('code', '');
        exit(true);
    end;

    /// <summary>Describes the existing refusal conditions.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'the definition is not an import definition');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    /// <summary>Declares the effects of this operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Data Exchange Type');
        Effect.Add('posts', false);
        exit(true);
    end;

    /// <summary>Declares the metering information for this message.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Lists related Data Exchange message types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add('DataExchange.Definition.Get');
        Related.Add('Storage.Upload.CommitToRecord');
        exit(true);
    end;

    /// <summary>Describes the existing Data Exchange workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides example inputs for the existing operation.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Summarizes the existing operation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates or updates a Data Exchange Type for incoming documents.';
        exit(true);
    end;

    /// <summary>Describes the limits of the currently implemented operation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The definition must be an import definition. Export definitions are rejected.';
        exit(true);
    end;

    /// <summary>Returns the direction of this message.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Executes the existing Data Exchange operation and writes its response to the argument.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DataExchangeType: Record "Data Exchange Type";
        DataExchDef: Record "Data Exch. Def";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        TypeCode: Code[20];
        DefinitionCode: Code[20];
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('code', Token) then begin
            Argument.RespondWithError('code is required.');
            exit;
        end;
        TypeCode := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(TypeCode));
        if not RequestJson.Get('dataExchDefCode', Token) then begin
            Argument.RespondWithError('dataExchDefCode is required.');
            exit;
        end;
        DefinitionCode := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(DefinitionCode));
        if not DataExchDef.Get(DefinitionCode) then begin
            Argument.RespondWithError('Data exchange definition ' + DefinitionCode + ' was not found.');
            exit;
        end;
        if DataExchDef.Type <> DataExchDef.Type::"Generic Import" then begin
            Argument.RespondWithError('definition must be an import definition');
            exit;
        end;
        if not DataExchangeType.Get(TypeCode) then begin
            DataExchangeType.Init();
            DataExchangeType.Code := TypeCode;
            DataExchangeType.Insert(true);
        end;
        DataExchangeType.Validate("Data Exch. Def. Code", DefinitionCode);
        if RequestJson.Get('description', Token) then
            DataExchangeType.Description := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(DataExchangeType.Description));
        DataExchangeType.Modify(true);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('code', DataExchangeType.Code);
        ResponseJson.Add('dataExchDefCode', DataExchangeType."Data Exch. Def. Code");
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
