namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Help.Storage.Get</c> message type. Returns a Markdown overview
/// of the storage connector, release baseline, and every message type it exposes.
/// No request body is required.
/// </summary>
codeunit 10035655 "Storage Help Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Returns a Markdown overview of the storage connector and all its message types. No request body is required.', Comment = 'is-IS=Skilar Markdown-yfirliti yfir geymslutengilinn og allar boðgerðir hans. Enginn meginmálshluti beiðni er nauðsynlegur.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'storage help, storage message types, how to use storage, storage API overview, storage documentation', Comment = 'is-IS=geymslu hjálp, geymsluboðgerðir, hvernig á að nota geymslu, yfirlit yfir geymslu API, geymsluskjöl';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Returns the storage connector guide and message type map; use a specific storage type to perform an operation.', Comment = 'is-IS=Skilar leiðbeiningum um geymslutengilinn og yfirliti yfir boðgerðir; notaðu tiltekna geymsluboðgerð til að framkvæma aðgerð.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(false);
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
        Response := ContractParts.GetResponse('Help.Storage.Get');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Help.Storage.Get');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Help.Storage.Get');
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
        Related := ContractParts.GetRelated('Help.Storage.Get');
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
    var
        OverviewLbl: Label 'Getting started: call Storage.Account.List, then use invoke_message_type and describe_message_type. Storage.Upload.Begin uses the bifrost-uploads/ default root.', Comment = 'is-IS=Fyrstu skref: kallaðu á Storage.Account.List og notaðu síðan invoke_message_type og describe_message_type. Storage.Upload.Begin notar sjálfgefnu rótina bifrost-uploads/.';
    begin
        Overview := OverviewLbl;
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
        Guide.AppendLine('# Bifrost Attachments - storage message types');
        Guide.AppendLine();
        Guide.AppendLine('Read and write files in external storage (Azure Blob Storage, Azure File Share or SharePoint) through the Business Central external file storage connectors, stage large files in chunks and keep document attachments in storage instead of the database.');
        Guide.AppendLine();
        Guide.AppendLine('## Getting started');
        Guide.AppendLine();
        Guide.AppendLine('1. Call `Storage.Account.List` to see the storage connections set up on the Attachments Setup page. Each row has a `storageCode`.');
        Guide.AppendLine('2. Send that `storageCode` with every other storage call. Paths are relative to the base folder of the connection and use forward slashes; `.` and `..` segments, backslashes and double slashes are refused.');
        Guide.AppendLine('3. Read the full contract of one type with `Help.Implementation.Get` (subject = the message type).');
        Guide.AppendLine();
        Guide.AppendLine('## Message types');
        Guide.AppendLine();
        Guide.AppendLine('| Area | Message type | Purpose |');
        Guide.AppendLine('|---|---|---|');
        Guide.AppendLine('| Accounts | `Storage.Account.List` | Lists the configured storage connections. |');
        Guide.AppendLine('| Files | `Storage.File.List` | Lists the files in a folder. |');
        Guide.AppendLine('| Files | `Storage.File.Get` | Returns the content of one file as base64. |');
        Guide.AppendLine('| Files | `Storage.File.Exists` | Tells whether a file exists. |');
        Guide.AppendLine('| Files | `Storage.File.Create` | Writes a file from base64 content. |');
        Guide.AppendLine('| Files | `Storage.File.Copy` | Copies a file to a new path. |');
        Guide.AppendLine('| Files | `Storage.File.Move` | Moves or renames a file; a linked file keeps its attachment link. |');
        Guide.AppendLine('| Files | `Storage.File.Delete` | Deletes a file that no attachment uses. |');
        Guide.AppendLine('| Directories | `Storage.Directory.List` | Lists the subfolders of a folder. |');
        Guide.AppendLine('| Directories | `Storage.Directory.Exists` | Tells whether a folder exists. |');
        Guide.AppendLine('| Directories | `Storage.Directory.Create` | Creates a folder. |');
        Guide.AppendLine('| Directories | `Storage.Directory.Delete` | Deletes a folder that holds no linked file. |');
        Guide.AppendLine('| Attachments | `Storage.Attachment.Offload` | Moves the content of a document attachment to storage and links it. |');
        Guide.AppendLine('| Attachments | `Storage.Attachment.Restore` | Writes linked content back into the attachment and deletes the stored file. |');
        Guide.AppendLine('| Attachments | `Storage.Attachment.CreateLinked` | Creates an attachment on a record that points at an existing stored file. |');
        Guide.AppendLine('| Attachments | `Storage.Attachment.CreateForRecord` | Creates an attachment on a record from base64 content. |');
        Guide.AppendLine('| Uploads | `Storage.Upload.Begin` | Opens a chunked upload session. |');
        Guide.AppendLine('| Uploads | `Storage.Upload.Append` | Adds the next chunk to an open session. |');
        Guide.AppendLine('| Uploads | `Storage.Upload.Status` | Returns the state of a session. |');
        Guide.AppendLine('| Uploads | `Storage.Upload.Commit` | Assembles the chunks and writes the file to storage. |');
        Guide.AppendLine('| Uploads | `Storage.Upload.CommitToRecord` | Assembles the chunks and attaches the file to a record. |');
        Guide.AppendLine('| Uploads | `Storage.Upload.Abort` | Discards an open session and its chunks. |');
        Guide.AppendLine();
        Guide.AppendLine('## Chunked uploads');
        Guide.AppendLine();
        Guide.AppendLine('Use an upload session when a file is larger than one request can carry: `Storage.Upload.Begin`, then `Storage.Upload.Append` once per chunk in order, then `Storage.Upload.Commit` or `Storage.Upload.CommitToRecord`. `Storage.Upload.Begin` returns `chunkSizeHint` and `maxChunkBytes`. Files are written under the `bifrost-uploads/` root unless the request names a folder. A session belongs to the user who opened it.');
        Guide.AppendLine();
        Guide.AppendLine('## Linked files');
        Guide.AppendLine();
        Guide.AppendLine('A stored file that backs a document attachment is protected. Deleting it and writing a create, copy, move or upload commit onto its path are refused with `PreconditionFailed`; use `Storage.Attachment.Restore` to bring the content back first.');
        Guide.AppendLine();
        Guide.AppendLine('## Errors');
        Guide.AppendLine();
        Guide.AppendLine('A refused call answers `status = Error` with `code`, `parameter`, `received`, `expected` and `nextStep` for every problem found, so all problems can be fixed in one retry.');
        Guide.AppendLine();
        Guide.AppendLine('## Permissions');
        Guide.AppendLine();
        Guide.AppendLine('Assign the `BIFROST Attach ori` permission set. The Data Exchange message types are described by `Help.DataExchange.Get` and need `BIFROST DataExch ori`.');
        exit(Guide.ToText());
    end;
}
