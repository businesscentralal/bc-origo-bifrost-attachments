namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Markdown overview for <c>Help.DataExchange.Get</c>: pipeline, phases, decision tree and chaining.
/// </summary>
codeunit 70013530 "DataExch Overview Help ori"
{
    Access = Internal;

    /// <summary>Renders the Markdown help document for the Data Exchange overview.</summary>
    /// <param name="MessageType">The message type to document.</param>
    /// <param name="Argument">The message argument the rendered Markdown is written to.</param>
    procedure GetHelp(MessageType: Enum "Message Type ori"; var Argument: Record "Message Argument ori")
    begin
        case MessageType of
            MessageType::"Help.DataExchange.Get":
                Argument.SetResponseMarkdown(BuildOverview());
        end;
    end;

    /// <summary>Builds the Data Exchange discovery overview.</summary>
    /// <returns>The overview document as Markdown.</returns>
    procedure BuildOverview(): Text
    var
        Builder: TextBuilder;
    begin
        Builder.AppendLine('# Data Exchange — discovery');
        Builder.AppendLine('');
        Builder.AppendLine('Read-only view of Business Central Data Exchange definitions, incoming-document types and processed entries. Nothing is uploaded or written.');
        Builder.AppendLine('');
        Builder.AppendLine('Message types are outbound and exchange JSON. Invoke one with `call_message_type`, `type` = the message type name and `data` = its parameters.');
        Builder.AppendLine('');
        Builder.AppendLine('## Pipeline');
        Builder.AppendLine('');
        Builder.AppendLine('A definition (`Data Exch. Def`) describes a file: its type (import or export), file type, the reading/writing codeunit or XMLport, line definitions, column definitions and field mappings onto a target table.');
        Builder.AppendLine('');
        Builder.AppendLine('An incoming-document purpose is a `Data Exchange Type`: a code that points at one definition. The feedback, validation and data-handling codeunits live on that definition and are returned with the type.');
        Builder.AppendLine('');
        Builder.AppendLine('A processed file is a `Data Exch.` entry (the audit row: file name, definition, optional file content) plus `Data Exch. Field` rows (one parsed value per line and column).');
        Builder.AppendLine('');
        Builder.AppendLine('## Phases');
        Builder.AppendLine('');
        Builder.AppendLine('| Phase | What it adds | Status in this release |');
        Builder.AppendLine('|---|---|---|');
        Builder.AppendLine('| 0 Discovery | `Help.DataExchange.Get`, `DataExchange.Definition.List`/`Get`, `DataExchange.Type.List`, `DataExchange.Entry.List`/`Get` | Available |');
        Builder.AppendLine('| 2 Incoming documents | upload to an incoming document with a Data Exchange Type | Not in this release |');
        Builder.AppendLine('| 1 Generic import | `DataExchange.Import.Run`, `Storage.Upload.CommitToDataExchange`, process and delete | Not in this release |');
        Builder.AppendLine('| 3 Export | `DataExchange.Export.Run` | Not in this release |');
        Builder.AppendLine('| 4 Definition management | import and export a definition as XML | Not in this release |');
        Builder.AppendLine('');
        Builder.AppendLine('## Decision tree');
        Builder.AppendLine('');
        Builder.AppendLine('- Need to see which definitions exist before uploading anything → `DataExchange.Definition.List`.');
        Builder.AppendLine('- Need the columns and field mappings a definition expects → `DataExchange.Definition.Get` with that `code`.');
        Builder.AppendLine('- Need the incoming-document types and which definition each one uses → `DataExchange.Type.List`. An empty company returns `count` 0.');
        Builder.AppendLine('- Need processed files → `DataExchange.Entry.List`, then `DataExchange.Entry.Get` for one `entryNo`.');
        Builder.AppendLine('- Need to write a `Data Exch.` row → do not use `Data.Records.Set`. That write is blocked. The dedicated writers (`DataExchange.Import.Run` / `Storage.Upload.CommitToDataExchange`) arrive in a later phase.');
        Builder.AppendLine('');
        Builder.AppendLine('## Chaining');
        Builder.AppendLine('');
        Builder.AppendLine('1. `DataExchange.Definition.List` → read `code` (and `usedByDataExchangeTypes`).');
        Builder.AppendLine('2. `DataExchange.Definition.Get` with that `code` → read `lineDefs`, `columnDefs` and `mappings` before building a file.');
        Builder.AppendLine('3. `DataExchange.Type.List` → read `code` and `dataExchDefCode` when the caller is choosing an incoming-document type.');
        Builder.AppendLine('4. `DataExchange.Entry.List` → read `entryNo`.');
        Builder.AppendLine('5. `DataExchange.Entry.Get` with that `entryNo` → read `fields`. Pass `includeFileContent` true only when the file is at most 1 MB.');
        Builder.AppendLine('');
        Builder.AppendLine('## Response envelope');
        Builder.AppendLine('');
        Builder.AppendLine('- Success — `{ "status": "Success", "data": { ... } }`');
        Builder.AppendLine('- Failure — `{ "status": "Error", "error": "<message>" }`');
        Builder.AppendLine('');
        Builder.AppendLine('Lists return `count` and a named array (`definitions`, `types` or `entries`). Entry list and entry field pages also return `skip` and `take`.');
        exit(Builder.ToText());
    end;
}
