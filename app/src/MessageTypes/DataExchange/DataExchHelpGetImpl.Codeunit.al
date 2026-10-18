namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Help.DataExchange.Get</c>. Returns the Data Exchange discovery overview.
/// No request body is required.
/// </summary>
codeunit 70013521 "DataExch Help Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Returns a Markdown overview of Data Exchange discovery: pipeline, phases, decision tree and chaining.', Comment = 'is-IS=Skilar Markdown-yfirliti yfir uppgötvun gagnaskipta: ferli, áföngum, ákvörðunartré og keðjun.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'data exchange help, import discovery, data exchange overview', Comment = 'is-IS=gagnaskiptahjálp, uppgötvun innflutnings, yfirlit gagnaskipta';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Returns the Data Exchange discovery guide; use a specific Data Exchange type to inspect definitions or entries.', Locked = true;
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetDataExchangeEnvelope(false);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Help.DataExchange.Get');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Help.DataExchange.Get');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Help.DataExchange.Get');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('Help.DataExchange.Get');
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
        Overview := 'Returns the Data Exchange discovery overview. Use invoke_message_type to call a type and describe_message_type to inspect its contract.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
        DataObject: JsonObject;
    begin
        Argument.AssertVersion1();
        DataObject.Add('format', 'markdown');
        DataObject.Add('markdown', BuildGuide());
        RequestMgt.RespondSuccess(Argument, DataObject);
    end;

    // The guide is a machine-facing contract document in English, like Foundation's Help.Bifrost.Get overview.
    local procedure BuildGuide(): Text
    var
        Guide: TextBuilder;
    begin
        Guide.AppendLine('# Bifrost Attachments - Data Exchange message types');
        Guide.AppendLine();
        Guide.AppendLine('Discover and prepare the Business Central Data Exchange Framework (Data Exch. Def, Data Exchange Type and Data Exch. entries) without the user interface. These types do not use a storage connection.');
        Guide.AppendLine();
        Guide.AppendLine('## Pipeline');
        Guide.AppendLine();
        Guide.AppendLine('1. **Discover** the definitions: `DataExchange.Definition.List` (optional `type` and `direction` filters), then `DataExchange.Definition.Get` for the lines, columns and mappings of one definition.');
        Guide.AppendLine('2. **Wire** an import definition to incoming documents: `DataExchange.Type.List` shows the Data Exchange Types, `DataExchange.Type.Set` creates or updates one for a Generic Import definition. Then `Storage.Upload.CommitToRecord` or `Storage.Attachment.CreateLinked` with `dataExchangeType` and optional `process`.');
        Guide.AppendLine('3. **Register** an entry: `DataExchange.Import.Run` (Generic Import or Payroll Import definition) or `DataExchange.Export.Run` (any definition that is not Generic Import). Both create a Data Exch. header only; they do not read or write a file.');
        Guide.AppendLine('4. **Inspect** entries: `DataExchange.Entry.List` (filter on `dataExchDefCode`, `dateFrom`, `dateTo`; page with `skip`/`take`), then `DataExchange.Entry.Get` for one entry and its fields (`includeFileContent` up to 1 MB).');
        Guide.AppendLine();
        Guide.AppendLine('## Which type do I need?');
        Guide.AppendLine();
        Guide.AppendLine('| I want to | Message type |');
        Guide.AppendLine('|---|---|');
        Guide.AppendLine('| Find a definition code | `DataExchange.Definition.List` |');
        Guide.AppendLine('| See how a definition maps columns to fields | `DataExchange.Definition.Get` |');
        Guide.AppendLine('| Get only the code, name and type of a definition | `DataExchange.Definition.Export` |');
        Guide.AppendLine('| Remove a definition no type or bank setup uses | `DataExchange.Definition.Delete` |');
        Guide.AppendLine('| See which Data Exchange Types exist | `DataExchange.Type.List` |');
        Guide.AppendLine('| Bind a Data Exchange Type to an import definition | `DataExchange.Type.Set` |');
        Guide.AppendLine('| Create an import entry header | `DataExchange.Import.Run` |');
        Guide.AppendLine('| Create an export entry header | `DataExchange.Export.Run` |');
        Guide.AppendLine('| List or read processed entries | `DataExchange.Entry.List`, `DataExchange.Entry.Get` |');
        Guide.AppendLine();
        Guide.AppendLine('## Chaining');
        Guide.AppendLine();
        Guide.AppendLine('Every code a list returns is the exact value the next call expects: `code` from `DataExchange.Definition.List` goes into `code` of `DataExchange.Definition.Get`, `DataExchange.Definition.Export` and `DataExchange.Definition.Delete`, and into `dataExchDefCode` of `DataExchange.Type.Set`, `DataExchange.Import.Run`, `DataExchange.Export.Run` and `DataExchange.Entry.List`. `entryNo` from `DataExchange.Import.Run`, `DataExchange.Export.Run` or `DataExchange.Entry.List` goes into `DataExchange.Entry.Get`. Codes are never trimmed, upper-cased or shortened; send them exactly as returned.');
        Guide.AppendLine();
        Guide.AppendLine('## Errors');
        Guide.AppendLine();
        Guide.AppendLine('A refused call answers `status = Error` with `code`, `parameter`, `received`, `expected` and `nextStep` for every problem found. Read `Help.Implementation.Get` (subject = the message type) for the full contract of one type.');
        Guide.AppendLine();
        Guide.AppendLine('## Permissions');
        Guide.AppendLine();
        Guide.AppendLine('Assign the `BIFROST DataExch ori` permission set. It grants the Data Exchange tables these types read and write; `BIFROST Attach ori` does not include them.');
        exit(Guide.ToText());
    end;
}
