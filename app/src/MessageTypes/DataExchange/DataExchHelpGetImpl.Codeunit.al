namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Help.DataExchange.Get</c>. Returns the Data Exchange discovery overview.
/// No request body is required.
/// </summary>
codeunit 10035165 "DataExch Help Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Returns a Markdown overview of the Data Exchange types: pipeline, decision table, chaining and permissions.', Comment = 'is-IS=Skilar Markdown-yfirliti yfir skilaboðategundir gagnaskipta: ferli, ákvörðunartöflu, keðjun og heimildir.';
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
        Overview := 'Returns the Data Exchange overview: install definitions, import and process files, export records and payment journals. Use invoke_message_type to call a type and describe_message_type to inspect its contract.';
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
        Guide.AppendLine('Run the Business Central Data Exchange Framework (Data Exch. Def, Data Exchange Type and Data Exch. entries) without the user interface: install definitions, import files into parsed entries, apply the mappings, and export records or payment journals to files in storage.');
        Guide.AppendLine();
        Guide.AppendLine('## Pipeline');
        Guide.AppendLine();
        Guide.AppendLine('1. **Install or discover** a definition: `DataExchange.Definition.Import` installs the standard definition XML (`storageCode` + `path`, `contentBase64` up to 1 MB, or a chunked `uploadId`; `overwrite`, `newCode`). `DataExchange.Definition.List` and `DataExchange.Definition.Get` show what exists; `DataExchange.Definition.Export` returns the header by default; `inline: true` adds the XML, and `storageCode` + `path`/`folderPath` writes the XML to storage. Both XML destinations may be requested. Storage writes can overwrite a file and cannot be rolled back.');
        Guide.AppendLine('2. **Import** a file with a Generic Import or Payroll Import definition: `DataExchange.Import.Run` (`storageCode` + `path` of a stored file, which stays unchanged, or `contentBase64` up to 1 MB) or, for a large file, `Storage.Upload.Begin` -> `Storage.Upload.Append` -> `Storage.Upload.CommitToDataExchange` (`uploadId`, `dataExchDefCode`, optional `keepFileInStorage`). Both create a Data Exch. entry, run the definition reader and return `entryNo`, `lineCount` and `fieldCount`. A file the reader cannot read is refused and leaves no entry.');
        Guide.AppendLine('3. **Inspect** the parsed fields: `DataExchange.Entry.Get` (`entryNo`, paged `fields`), `DataExchange.Entry.List` for older entries.');
        Guide.AppendLine('4. **Process** the entry: `DataExchange.Entry.Process` runs the definition mappings and returns `targets[]` (table, inserted and modified counts, record SystemIds). Or send `process: true` on the import to do both in one call; the import is then committed first, and a processing error is returned in `processResult.errors` while the entry stays.');
        Guide.AppendLine('5. **Export**: `DataExchange.Export.Run` runs a Generic Export definition over `tableId`/`tableName` with `tableView`, or over `recordIds`, and delivers the file to storage (`storageCode` + `path` or `folderPath`) and/or `inline` (up to 1 MB). `DataExchange.PaymentExport.Run` exports a payment journal batch (`journalTemplate`, `journalBatch`) with the payment export format of its bank account, marks the lines as exported and delivers the bank file.');
        Guide.AppendLine('6. **Clean up**: `DataExchange.Entry.Delete` deletes an entry and its fields. Entries created by these types are also removed by the retention policy on Bifrost Data Exchange Entry (30 days by default).');
        Guide.AppendLine();
        Guide.AppendLine('Incoming documents are the other import path: wire a Generic Import definition that maps to the intermediate table with `DataExchange.Type.Set`, then send the file with `Storage.Upload.CommitToRecord` or `Storage.Attachment.CreateLinked` (`target` IncomingDocument, `dataExchangeType`, `process`). `DataExchange.Entry.Process` refuses intermediate-table mappings and points there. Bank statements are imported with `Finance.BankReconciliation.Create`.');
        Guide.AppendLine();
        Guide.AppendLine('## Which type do I need?');
        Guide.AppendLine();
        Guide.AppendLine('| I want to | Message type |');
        Guide.AppendLine('|---|---|');
        Guide.AppendLine('| Find a definition code | `DataExchange.Definition.List` |');
        Guide.AppendLine('| See how a definition maps columns to fields | `DataExchange.Definition.Get` |');
        Guide.AppendLine('| Install a definition from its XML | `DataExchange.Definition.Import` |');
        Guide.AppendLine('| Get a definition as XML, or only its header | `DataExchange.Definition.Export` |');
        Guide.AppendLine('| Remove a definition nothing uses | `DataExchange.Definition.Delete` |');
        Guide.AppendLine('| See which Data Exchange Types exist | `DataExchange.Type.List` |');
        Guide.AppendLine('| Bind a Data Exchange Type to an import definition | `DataExchange.Type.Set` |');
        Guide.AppendLine('| Import a stored file or small inline content | `DataExchange.Import.Run` |');
        Guide.AppendLine('| Import a large file sent in chunks | `Storage.Upload.CommitToDataExchange` |');
        Guide.AppendLine('| Write the parsed lines to the business tables | `DataExchange.Entry.Process` |');
        Guide.AppendLine('| Export records to a file | `DataExchange.Export.Run` |');
        Guide.AppendLine('| Create the bank payment file of a payment journal | `DataExchange.PaymentExport.Run` |');
        Guide.AppendLine('| List, read or delete entries | `DataExchange.Entry.List`, `DataExchange.Entry.Get`, `DataExchange.Entry.Delete` |');
        Guide.AppendLine();
        Guide.AppendLine('## Chaining');
        Guide.AppendLine();
        Guide.AppendLine('Every code a list returns is the exact value the next call expects: `code` from `DataExchange.Definition.List` or `codes[]` from `DataExchange.Definition.Import` goes into `code` of `DataExchange.Definition.Get`, `DataExchange.Definition.Export` and `DataExchange.Definition.Delete`, and into `dataExchDefCode` of `DataExchange.Type.Set`, `DataExchange.Import.Run`, `Storage.Upload.CommitToDataExchange`, `DataExchange.Export.Run` and `DataExchange.Entry.List`. `entryNo` from an import, an export or `DataExchange.Entry.List` goes into `DataExchange.Entry.Get`, `DataExchange.Entry.Process` and `DataExchange.Entry.Delete`. `storageCode` and `path` of an export go into `Storage.File.Get`. Codes are never trimmed, upper-cased or shortened; send them exactly as returned.');
        Guide.AppendLine();
        Guide.AppendLine('## Errors');
        Guide.AppendLine();
        Guide.AppendLine('A refused call answers `status = Error` with `code`, `parameter`, `received`, `expected` and `nextStep` for every problem found. A failure after a write (a reader or mapping error, a file over 1 MB with `inline`, a failed storage write) rolls the call back. Read `Help.Implementation.Get` (subject = the message type) for the full contract of one type.');
        Guide.AppendLine();
        Guide.AppendLine('## Permissions');
        Guide.AppendLine();
        Guide.AppendLine('Assign `BIFROST DataExch ori` with the Foundation API baseline. This role grants table read access, including the definition read by `DataExchange.Definition.Export`; it does not grant table writes. Definition.Export is registered Inbound because its optional storage output writes an external file; the storage connector also requires its own permissions.');
        Guide.AppendLine('The write types additionally require the standard Business Central permissions of the tables they write: Data Exch. and Data Exch. Field for imports and exports, the definition tables for `DataExchange.Definition.Import` and `DataExchange.Definition.Delete`, the target tables of the mappings for processing, and Gen. Journal Line and Credit Transfer Register for payment exports. Types with `storageCode` also use the storage connection. `BIFROST Attach ori` does not grant these Data Exchange table permissions.');
        exit(Guide.ToText());
    end;
}
