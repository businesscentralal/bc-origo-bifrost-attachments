namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;
using System.Utilities;

codeunit 70013545 "DataExch Def Import Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Imports a data exchange definition from XML.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('data exchange definition import, xml');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Installs a data exchange definition from definitionXml.');
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
        Parameter.Add('name', 'definitionXml');
        Parameter.Add('type', 'string');
        Parameter.Add('required', true);
        Parameter.Add('description', 'Data exchange definition XML.');
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
        Related.Add('DataExchange.Definition.Export');
        Related.Add('DataExchange.Definition.Get');
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
        Overview := 'Imports a data exchange definition from XML through the standard import.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The compiler still needs to confirm the definition import procedure.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DataExchDef: Record "Data Exch. Def";
        TempBlob: Codeunit "Temp Blob";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DefinitionXml: Text;
        OutStream: OutStream;
        InStream: InStream;
        MissingErr: Label 'definitionXml is required.', Locked = true;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('definitionXml', Token) then begin
            Argument.RespondWithError(MissingErr);
            exit;
        end;
        DefinitionXml := Token.AsValue().AsText();
        TempBlob.CreateOutStream(OutStream);
        OutStream.WriteText(DefinitionXml);
        TempBlob.CreateInStream(InStream);
        DataExchDef.ImportFromStream(InStream);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'DataExchange.Definition.Import');
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
