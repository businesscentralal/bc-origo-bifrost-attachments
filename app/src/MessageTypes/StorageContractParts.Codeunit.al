namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>Builds the shared contract chapters for Bifröst Attachments message types.</summary>
codeunit 70013500 "Storage Contract Parts ori"
{
    Access = Internal;

    var
        DataExchangeFailureLbl: Label 'Business Central cannot complete the Data Exchange operation.', Comment = 'is-IS=Business Central getur ekki lokið gagnaskiptaaðgerðinni.';
        DataExchangeFailureFixLbl: Label 'Check the supplied definition or entry and the Business Central error details.', Comment = 'is-IS=Athugaðu uppgefna skilgreiningu eða færslu og villuupplýsingar Business Central.';
        PagingSkipLbl: Label 'Number of rows or fields skipped.', Comment = 'is-IS=Fjöldi færslna eða reita sem var sleppt.';
        PagingTakeLbl: Label 'Effective page size.', Comment = 'is-IS=Virk síðustærð.';
        SkipDescriptionLbl: Label 'Rows or fields to skip; a nonnegative integer.', Comment = 'is-IS=Færslur eða reitir sem á að sleppa; heiltala sem er ekki neikvæð.';
        TakeDescriptionLbl: Label 'Page size from 0 to 1000. Omitted or 0 uses 100; larger values are refused.', Comment = 'is-IS=Síðustærð frá 0 til 1000. Sleppi eða 0 notar 100; hærri gildum er hafnað.';
        AttachmentStorageLbl: Label 'Required with path when attaching a stored file. Omit for inline content or a source attachment.', Comment = 'is-IS=Nauðsynlegt með path þegar skrá úr geymslu er hengd við. Slepptu fyrir innfellt innihald eða upprunaviðhengi.';
        SourceTargetLbl: Label 'Required with sourceSystemId: IncomingDocument or DocumentAttachment. Choose exactly one source: contentBase64 (or content), storageCode with path, or sourceTarget with sourceSystemId.', Comment = 'is-IS=Nauðsynlegt með sourceSystemId: IncomingDocument eða DocumentAttachment. Veldu nákvæmlega eina uppsprettu: contentBase64 (eða content), storageCode með path eða sourceTarget með sourceSystemId.';
        SourceSystemIdLbl: Label 'The source attachment SystemId; required with sourceTarget.', Comment = 'is-IS=SystemId upprunaviðhengis; nauðsynlegt með sourceTarget.';
        UploadStorageLbl: Label 'Required for Storage.Upload.Commit to storage. Omit when the session will use Storage.Upload.CommitToRecord.', Comment = 'is-IS=Nauðsynlegt fyrir Storage.Upload.Commit í geymslu. Slepptu þegar lotan mun nota Storage.Upload.CommitToRecord.';
        UploadTableIdLbl: Label 'The host record table id; use tableId or tableName for DocumentAttachment. Not used for IncomingDocument.', Comment = 'is-IS=Töfluauðkenni hýsilfærslu; notaðu tableId eða tableName fyrir DocumentAttachment. Ekki notað fyrir IncomingDocument.';
        UploadTableNameLbl: Label 'Accepted table name instead of tableId for DocumentAttachment.', Comment = 'is-IS=Heiti töflu sem má nota í stað tableId fyrir DocumentAttachment.';
        IncomingDescriptionLbl: Label 'Description for a new IncomingDocument; ignored for DocumentAttachment.', Comment = 'is-IS=Lýsing fyrir nýtt IncomingDocument; hunsað fyrir DocumentAttachment.';
        UploadRecordIdLbl: Label 'For DocumentAttachment, identify the host by recordSystemId or no; required for tables without no addressing.', Comment = 'is-IS=Fyrir DocumentAttachment skal auðkenna hýsil með recordSystemId eða no; nauðsynlegt fyrir töflur án no-vistfangs.';
        TypeCodeLbl: Label 'The Data Exchange Type code, at most 20 characters.', Comment = 'is-IS=Kóði gagnaskiptagerðar, að hámarki 20 stafir.';
        ImportDefinitionLbl: Label 'The existing import definition code, at most 20 characters.', Comment = 'is-IS=Kóði fyrirliggjandi innflutningsskilgreiningar, að hámarki 20 stafir.';
        ExportDefinitionLbl: Label 'The existing export definition code, at most 20 characters.', Comment = 'is-IS=Kóði fyrirliggjandi útflutningsskilgreiningar, að hámarki 20 stafir.';
        TypeDescriptionLbl: Label 'Optional description within the Data Exchange Type Description field length.', Comment = 'is-IS=Valfrjáls lýsing innan lengdar lýsingarreits gagnaskiptagerðar.';
        ImportPathLbl: Label 'The file path relative to the storage connection base path.', Comment = 'is-IS=Skráarslóð miðað við grunnslóð geymslutengingar.';
        ExportFileNameLbl: Label 'The output file name within the Data Exch. File Name field length.', Comment = 'is-IS=Heiti úttaksskrár innan lengdar skráarheitisreits gagnaskipta.';
        DefinitionCodeLbl: Label 'The complete Data Exchange definition code, at most 20 characters.', Comment = 'is-IS=Allur kóði gagnaskiptaskilgreiningar, að hámarki 20 stafir.';
        UploadResponseStorageLbl: Label 'The session storage connection code; empty for a record-only upload.', Comment = 'is-IS=Geymslutengingarkóði lotunnar; tómt fyrir upphleðslu eingöngu í færslu.';
        ChunkSizeHintLbl: Label 'The recommended raw chunk size in bytes.', Comment = 'is-IS=Ráðlögð stærð hrárrar gagnaeiningar í bætum.';
        UploadFileNameLbl: Label 'The session file name.', Comment = 'is-IS=Skráarheiti lotunnar.';
        UploadPathLbl: Label 'The session storage path.', Comment = 'is-IS=Geymsluslóð lotunnar.';
        DeclaredSizeLbl: Label 'The declared file size in bytes.', Comment = 'is-IS=Uppgefin skráarstærð í bætum.';
        DefinitionNameLbl: Label 'The definition name.', Comment = 'is-IS=Heiti skilgreiningar.';
        DefinitionTypeLbl: Label 'The definition type name.', Comment = 'is-IS=Gerðarheiti skilgreiningar.';
        CreatedEntryLbl: Label 'The created Data Exchange entry number.', Comment = 'is-IS=Númer gagnaskiptafærslunnar sem var stofnuð.';
        MatchingCountLbl: Label 'Number of matching rows.', Comment = 'is-IS=Fjöldi samsvarandi færslna.';
        MatchingTypesLbl: Label 'The Data Exchange Types and their linked definitions.', Comment = 'is-IS=Gagnaskiptagerðir og tengdar skilgreiningar þeirra.';
        MissingInputLbl: Label 'A required request parameter is missing.', Comment = 'is-IS=Nauðsynlega færibreytu vantar í beiðnina.';
        SupplyInputLbl: Label 'Provide the named parameter and retry.', Comment = 'is-IS=Gefðu upp tilgreinda færibreytu og reyndu aftur.';
        InvalidFormatLbl: Label 'A parameter has the wrong JSON type or format.', Comment = 'is-IS=Færibreyta hefur ranga JSON-gerð eða snið.';
        CorrectInputLbl: Label 'Correct every reported parameter using expected and nextStep, then retry.', Comment = 'is-IS=Leiðréttu allar tilgreindar færibreytur samkvæmt expected og nextStep og reyndu aftur.';
        InvalidInputLbl: Label 'A parameter is outside the allowed values or length.', Comment = 'is-IS=Færibreyta er utan leyfilegra gilda eða lengdar.';
        MultipleInputLbl: Label 'Several parameters are invalid; errors lists every problem.', Comment = 'is-IS=Margar færibreytur eru ógildar; errors telur upp öll vandamálin.';
        MissingRecordLbl: Label 'The supplied definition code does not exist.', Comment = 'is-IS=Uppgefinn skilgreiningarkóði er ekki til.';
        ChooseRecordLbl: Label 'Choose an existing compatible definition using DataExchange.Definition.List.', Comment = 'is-IS=Veldu fyrirliggjandi samhæfa skilgreiningu með DataExchange.Definition.List.';
        UnusableDefinitionLbl: Label 'The definition is referenced or incompatible with this operation.', Comment = 'is-IS=Vísað er í skilgreininguna eða hún er ósamhæf við þessa aðgerð.';
        InlineLimitLbl: Label 'The requested inline file content exceeds 1 MiB.', Comment = 'is-IS=Umbeðið innfellt skráarinnihald er yfir 1 MiB.';
        OmitInlineLbl: Label 'Omit includeFileContent or send false and retrieve the file through storage.', Comment = 'is-IS=Slepptu includeFileContent eða sendu false og sæktu skrána í gegnum geymslu.';
        DataExchangeChangesLbl: Label 'Writes Data Exchange definition, type or entry records within the operation transaction. Import.Run and Export.Run currently stage an entry header only.', Comment = 'is-IS=Skrifar skilgreiningar, gerðir eða færslur gagnaskipta innan færslubókunar aðgerðarinnar. Import.Run og Export.Run undirbúa nú aðeins færsluhaus.';
        DataExchangePreconditionsLbl: Label 'The caller may access Data Exchange; supplied definitions and entries must exist and support the operation. Storage is required only for DataExchange.Import.Run.', Comment = 'is-IS=Kallandi má nálgast gagnaskipti; uppgefnar skilgreiningar og færslur verða að vera til og styðja aðgerðina. Geymsla er aðeins nauðsynleg fyrir DataExchange.Import.Run.';


    /// <summary>Builds the envelope shared by storage requests.</summary>
    procedure GetEnvelope(DataRequired: Boolean) Envelope: JsonObject
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The storage message is identified by its message type; it has no subject record.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', DataRequired);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
    end;

    /// <summary>Builds the request parameters read by one message type.</summary>
    procedure GetParameters(MessageType: Text) Parameters: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType in ['Storage.Account.List', 'Help.Storage.Get', 'Help.DataExchange.Get', 'DataExchange.Type.List'] then
            exit;

        if not (MessageType in ['Storage.Attachment.Restore', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.Append', 'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.Status', 'DataExchange.Definition.Get', 'DataExchange.Entry.Get', 'DataExchange.Definition.List', 'DataExchange.Entry.List', 'DataExchange.Type.Set', 'DataExchange.Definition.Delete', 'DataExchange.Definition.Export', 'DataExchange.Export.Run', 'Storage.Upload.Begin', 'Storage.Upload.CommitToRecord']) then
            Parameters.Add(ContractMgt.Parameter('storageCode', 'string', true, 'The configured storage connection code. Resolve it with Storage.Account.List.'));
        case MessageType of
            'Storage.File.List', 'Storage.Directory.List':
                Parameters.Add(ContractMgt.Parameter('path', 'string', false, 'The directory path relative to the connection base path.'));
            'Storage.File.Get', 'Storage.File.Delete', 'Storage.File.Exists', 'Storage.Directory.Create', 'Storage.Directory.Delete', 'Storage.Directory.Exists':
                Parameters.Add(ContractMgt.Parameter('path', 'string', true, 'The file or directory path relative to the connection base path.'));
            'Storage.File.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('path', 'string', true, 'The destination file path relative to the connection base path.'));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', true, 'The complete file content encoded as base64.'));
                end;
            'Storage.File.Copy', 'Storage.File.Move':
                begin
                    Parameters.Add(ContractMgt.Parameter('sourcePath', 'string', true, 'The source file path relative to the connection base path.'));
                    Parameters.Add(ContractMgt.Parameter('targetPath', 'string', true, 'The destination file path relative to the connection base path.'));
                end;
            'Storage.Attachment.Offload':
                begin
                    Parameters.Add(ContractMgt.Parameter('target', 'string', true, 'The attachment table: IncomingDocument or DocumentAttachment.'));
                    Parameters.Add(ContractMgt.Parameter('systemId', 'string', true, 'The attachment SystemId.'));
                    Parameters.Add(ContractMgt.Parameter('folderPath', 'string', false, 'Optional destination folder.'));
                end;
            'Storage.Attachment.Restore':
                begin
                    Parameters.Add(ContractMgt.Parameter('target', 'string', true, 'The attachment table: IncomingDocument or DocumentAttachment.'));
                    Parameters.Add(ContractMgt.Parameter('systemId', 'string', true, 'The attachment SystemId.'));
                end;
            'Storage.Attachment.CreateLinked':
                begin
                    Parameters.Add(ContractMgt.Parameter('path', 'string', true, 'The file path in storage.'));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', true, 'The attachment file name.'));
                    Parameters.Add(ContractMgt.Parameter('incomingDocumentEntryNo', 'integer', false, 'An existing incoming document entry number.'));
                    Parameters.Add(ContractMgt.Parameter('description', 'string', false, 'Description for a new incoming document.'));
                end;
            'Storage.Attachment.CreateForRecord':
                begin
                    Parameters.Add(ContractMgt.Parameter('storageCode', 'string', false, AttachmentStorageLbl));
                    Parameters.Add(ContractMgt.Parameter('sourceTarget', 'string', false, SourceTargetLbl));
                    Parameters.Add(ContractMgt.Parameter('sourceSystemId', 'string', false, SourceSystemIdLbl));
                    Parameters.Add(ContractMgt.Parameter('tableId', 'integer', false, 'The host record table id.'));
                    Parameters.Add(ContractMgt.Parameter('tableName', 'string', false, 'The host record table name.'));
                    Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'The host record SystemId.'));
                    Parameters.Add(ContractMgt.Parameter('no', 'string', false, 'The host record primary key.'));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', false, 'The attachment file name.'));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', false, 'Inline file content encoded as base64.'));
                    Parameters.Add(ContractMgt.Parameter('content', 'string', false, 'Accepted alias of contentBase64. Do not send both.'));
                    Parameters.Add(ContractMgt.Parameter('path', 'string', false, 'The source file path in storage.'));
                end;
            'Storage.Upload.Begin':
                begin
                    Parameters.Add(ContractMgt.Parameter('storageCode', 'string', false, UploadStorageLbl));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', true, 'The leaf file name.'));
                    Parameters.Add(ContractMgt.Parameter('path', 'string', false, 'The full destination path.'));
                    Parameters.Add(ContractMgt.Parameter('folderPath', 'string', false, 'The destination folder.'));
                    Parameters.Add(ContractMgt.Parameter('declaredSize', 'integer', false, 'The expected total size in bytes.'));
                end;
            'Storage.Upload.Append':
                begin
                    Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, 'The upload session id.'));
                    Parameters.Add(ContractMgt.Parameter('sequence', 'integer', true, 'The one-based chunk sequence.'));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', true, 'The chunk content encoded as base64.'));
                end;
            'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.Status':
                Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, 'The upload session id.'));
            'Storage.Upload.CommitToRecord':
                begin
                    Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, 'The upload session id.'));
                    Parameters.Add(ContractMgt.Parameter('target', 'string', false, 'DocumentAttachment or IncomingDocument.'));
                    Parameters.Add(ContractMgt.Parameter('tableId', 'integer', false, UploadTableIdLbl));
                    Parameters.Add(ContractMgt.Parameter('tableName', 'string', false, UploadTableNameLbl));
                    Parameters.Add(ContractMgt.Parameter('description', 'string', false, IncomingDescriptionLbl));
                    Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, UploadRecordIdLbl));
                    Parameters.Add(ContractMgt.Parameter('no', 'string', false, 'The host record primary key.'));
                    Parameters.Add(ContractMgt.Parameter('incomingDocumentEntryNo', 'integer', false, 'An existing incoming document entry number.'));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', false, 'An optional replacement file name.'));
                end;
            'DataExchange.Definition.List':
                begin
                    Parameters.Add(ContractMgt.Parameter('type', 'string', false, 'Optional definition type filter.'));
                    Parameters.Add(ContractMgt.Parameter('direction', 'string', false, 'Import or Export.'));
                end;
            'DataExchange.Definition.Get', 'DataExchange.Definition.Delete', 'DataExchange.Definition.Export':
                Parameters.Add(ContractMgt.Parameter('code', 'string', true, DefinitionCodeLbl));
            'DataExchange.Entry.List':
                begin
                    Parameters.Add(ContractMgt.Parameter('dataExchDefCode', 'string', false, 'Optional definition code filter.'));
                    Parameters.Add(ContractMgt.Parameter('dateFrom', 'string', false, 'Inclusive start date or datetime.'));
                    Parameters.Add(ContractMgt.Parameter('dateTo', 'string', false, 'Inclusive end date or datetime.'));
                    Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, SkipDescriptionLbl));
                    Parameters.Add(ContractMgt.Parameter('take', 'integer', false, TakeDescriptionLbl));
                end;
            'DataExchange.Entry.Get':
                begin
                    Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', true, 'The Data Exchange entry number.'));
                    Parameters.Add(ContractMgt.Parameter('includeFields', 'boolean', false, 'Whether to include fields.'));
                    Parameters.Add(ContractMgt.Parameter('includeFileContent', 'boolean', false, 'Whether to include file content.'));
                    Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, SkipDescriptionLbl));
                    Parameters.Add(ContractMgt.Parameter('take', 'integer', false, TakeDescriptionLbl));
                end;
            'DataExchange.Type.Set':
                begin
                    Parameters.Add(ContractMgt.Parameter('code', 'string', true, TypeCodeLbl));
                    Parameters.Add(ContractMgt.Parameter('dataExchDefCode', 'string', true, ImportDefinitionLbl));
                    Parameters.Add(ContractMgt.Parameter('description', 'string', false, TypeDescriptionLbl));
                end;
            'DataExchange.Import.Run':
                begin
                    Parameters.Add(ContractMgt.Parameter('dataExchDefCode', 'string', true, ImportDefinitionLbl));
                    Parameters.Add(ContractMgt.Parameter('path', 'string', true, ImportPathLbl));
                end;
            'DataExchange.Export.Run':
                begin
                    Parameters.Add(ContractMgt.Parameter('dataExchDefCode', 'string', true, ExportDefinitionLbl));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', true, ExportFileNameLbl));
                end;

        end;
    end;

    /// <summary>Builds the target chapter for attachment records.</summary>
    procedure GetAttachmentTarget() Target: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.target + data.systemId', 'attachment record', 'The attachment table and SystemId identify the attachment.'));
    end;

    /// <summary>Describes the existing record addressed by a shipped Data Exchange operation.</summary>
    /// <param name="MessageType">The registered message type.</param>
    /// <returns>The record address expressed through Foundation target entries.</returns>
    procedure GetDataExchangeTarget(MessageType: Text) Target: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'DataExchange.Type.Set':
                Target.Add(ContractMgt.TargetEntry('data.code', 'Data Exchange Type', TypeCodeLbl));
            'DataExchange.Definition.Delete', 'DataExchange.Definition.Export':
                Target.Add(ContractMgt.TargetEntry('data.code', 'Data Exch. Def', DefinitionCodeLbl));
            'DataExchange.Import.Run', 'DataExchange.Export.Run':
                Target.Add(ContractMgt.TargetEntry('data.dataExchDefCode', 'Data Exch. Def', DefinitionCodeLbl));
        end;
    end;

    /// <summary>Builds the success response fields for one message type.</summary>
    procedure GetResponse(MessageType: Text) Response: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        case MessageType of
            'Help.Storage.Get':
                Fields.Add(ContractMgt.ResponseField('markdown', 'string', 'The storage connector overview and message type guidance.'));
            'Help.DataExchange.Get':
                Fields.Add(ContractMgt.ResponseField('markdown', 'string', 'The Data Exchange discovery overview and workflow guidance.'));
            'Storage.Account.List':
                Fields.Add(ContractMgt.ResponseField('accounts', 'array', 'Configured storage connections without secrets.'));
            'Storage.File.List', 'Storage.Directory.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The requested directory path.'));
                    Fields.Add(ContractMgt.ResponseField('entries', 'array', 'The files or directories found at the path.'));
                end;
            'Storage.File.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The downloaded file path.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                    Fields.Add(ContractMgt.ResponseField('contentBase64', 'string', 'The file content encoded as base64.'));
                end;
            'Storage.File.Exists', 'Storage.Directory.Exists':
                begin
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The checked path.'));
                    Fields.Add(ContractMgt.ResponseField('exists', 'boolean', 'Whether the path exists.'));
                end;
            'Storage.File.Create', 'Storage.File.Delete', 'Storage.File.Copy', 'Storage.File.Move', 'Storage.Directory.Create', 'Storage.Directory.Delete':
                Fields.Add(ContractMgt.ResponseField('path', 'string', 'The affected path.'));
            'Storage.Attachment.Offload':
                begin
                    Fields.Add(ContractMgt.ResponseField('target', 'string', 'The attachment table.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The attachment SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The storage path.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                end;
            'Storage.Attachment.Restore':
                begin
                    Fields.Add(ContractMgt.ResponseField('target', 'string', 'The attachment table.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The attachment SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                end;
            'Storage.Attachment.CreateLinked', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.CommitToRecord':
                begin
                    Fields.Add(ContractMgt.ResponseField('target', 'string', 'The attachment target.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The new attachment SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('fileName', 'string', 'The final attachment file name.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                end;
            'Storage.Upload.Begin':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('storageCode', 'string', UploadResponseStorageLbl));
                    Fields.Add(ContractMgt.ResponseField('chunkSizeHint', 'integer', ChunkSizeHintLbl));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The destination path.'));
                    Fields.Add(ContractMgt.ResponseField('maxChunkBytes', 'integer', 'The maximum raw chunk size.'));
                end;
            'Storage.Upload.Append':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('sequence', 'integer', 'The accepted chunk sequence.'));
                    Fields.Add(ContractMgt.ResponseField('received', 'integer', 'Bytes accumulated so far.'));
                end;
            'Storage.Upload.Commit':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The committed upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('storageCode', 'string', 'The storage connection.'));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The committed file path.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                end;
            'Storage.Upload.Abort':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The aborted upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'The resulting status.'));
                end;
            'Storage.Upload.Status':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('storageCode', 'string', UploadResponseStorageLbl));
                    Fields.Add(ContractMgt.ResponseField('fileName', 'string', UploadFileNameLbl));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', UploadPathLbl));
                    Fields.Add(ContractMgt.ResponseField('declaredSize', 'integer', DeclaredSizeLbl));
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'The upload state.'));
                    Fields.Add(ContractMgt.ResponseField('received', 'integer', 'Bytes accumulated so far.'));
                    Fields.Add(ContractMgt.ResponseField('chunkCount', 'integer', 'Chunks stored so far.'));
                end;
            'DataExchange.Type.Set':
                begin
                    Fields.Add(ContractMgt.ResponseField('code', 'string', TypeCodeLbl));
                    Fields.Add(ContractMgt.ResponseField('dataExchDefCode', 'string', ImportDefinitionLbl));
                end;
            'DataExchange.Definition.Delete':
                Fields.Add(ContractMgt.ResponseField('code', 'string', DefinitionCodeLbl));
            'DataExchange.Definition.Export':
                begin
                    Fields.Add(ContractMgt.ResponseField('code', 'string', DefinitionCodeLbl));
                    Fields.Add(ContractMgt.ResponseField('name', 'string', DefinitionNameLbl));
                    Fields.Add(ContractMgt.ResponseField('type', 'string', DefinitionTypeLbl));
                end;
            'DataExchange.Import.Run', 'DataExchange.Export.Run':
                begin
                    Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', CreatedEntryLbl));
                    Fields.Add(ContractMgt.ResponseField('dataExchDefCode', 'string', DefinitionCodeLbl));
                    if MessageType = 'DataExchange.Export.Run' then
                        Fields.Add(ContractMgt.ResponseField('fileName', 'string', ExportFileNameLbl));
                end;
            'DataExchange.Type.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('count', 'integer', MatchingCountLbl));
                    Fields.Add(ContractMgt.ResponseField('types', 'array', MatchingTypesLbl));
                end;
            'DataExchange.Definition.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('count', 'integer', 'Number of matching definitions.'));
                    Fields.Add(ContractMgt.ResponseField('definitions', 'array', 'Matching definitions.'));
                end;
            'DataExchange.Definition.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('code', 'string', 'The definition code.'));
                    Fields.Add(ContractMgt.ResponseField('lineDefs', 'array', 'Line definitions.'));
                    Fields.Add(ContractMgt.ResponseField('columnDefs', 'array', 'Column definitions.'));
                    Fields.Add(ContractMgt.ResponseField('mappings', 'array', 'Field mappings.'));
                end;
            'DataExchange.Type.List':
                Fields.Add(ContractMgt.ResponseField('types', 'array', 'Data Exchange Type rows.'));
            'DataExchange.Entry.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('skip', 'integer', PagingSkipLbl));
                    Fields.Add(ContractMgt.ResponseField('take', 'integer', PagingTakeLbl));
                    Fields.Add(ContractMgt.ResponseField('count', 'integer', 'Number of matching entries.'));
                    Fields.Add(ContractMgt.ResponseField('entries', 'array', 'Matching entries.'));
                end;
            'DataExchange.Entry.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('skip', 'integer', PagingSkipLbl));
                    Fields.Add(ContractMgt.ResponseField('take', 'integer', PagingTakeLbl));
                    Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The entry number.'));
                    Fields.Add(ContractMgt.ResponseField('fields', 'array', 'Paged entry fields.'));
                    Fields.Add(ContractMgt.ResponseField('contentBase64', 'string', 'Optional file content.'));
                end;
        end;
        Response.Add('fields', Fields);
    end;

    /// <summary>Builds the known errors returned by one message type.</summary>
    procedure GetErrors(MessageType: Text) Errors: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if not (MessageType in ['Storage.Account.List', 'Help.Storage.Get', 'Help.DataExchange.Get', 'DataExchange.Type.List']) then begin
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingInputLbl, SupplyInputLbl));
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, InvalidFormatLbl, CorrectInputLbl));
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidInputLbl, CorrectInputLbl));
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, MultipleInputLbl, CorrectInputLbl));
            if MessageType in ['DataExchange.Type.Set', 'DataExchange.Definition.Delete', 'DataExchange.Definition.Export', 'DataExchange.Import.Run', 'DataExchange.Export.Run'] then begin
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, MissingRecordLbl, ChooseRecordLbl));
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, UnusableDefinitionLbl, ChooseRecordLbl));
            end;
            if MessageType = 'DataExchange.Entry.Get' then
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, InlineLimitLbl, OmitInlineLbl));
        end;
        if MessageType in ['Storage.File.Create', 'Storage.Upload.Append'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'The contentBase64 value is not valid base64.', 'Send valid base64 content.'));
        if MessageType in ['Storage.File.Delete', 'Storage.Directory.Delete'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'A linked Business Central attachment prevents the delete.', 'Restore or remove the attachment first.'));
        if MessageType in ['Storage.Upload.Append', 'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.CommitToRecord'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The upload session is missing, closed or incomplete.', 'Begin a new session or complete the missing chunks.'));
        if MessageType in ['DataExchange.Definition.Get'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The definition code does not exist.', 'Use DataExchange.Definition.List first.'));
        if MessageType in ['DataExchange.Entry.Get'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The entry number does not exist.', 'Use DataExchange.Entry.List first.'));
        if MessageType.StartsWith('DataExchange.') then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, DataExchangeFailureLbl, DataExchangeFailureFixLbl))
        else
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The storage connector rejects or cannot complete the operation.', 'Check the path, connection and connector error details.'));
    end;

    /// <summary>Builds the operation effect for one message type.</summary>
    procedure GetEffect(MessageType: Text) Effect: JsonObject
    begin
        case true of
            MessageType in ['DataExchange.Type.Set', 'DataExchange.Definition.Delete', 'DataExchange.Import.Run', 'DataExchange.Export.Run']:
                begin
                    Effect.Add('effect', 'write');
                    Effect.Add('changes', DataExchangeChangesLbl);
                end;
            MessageType in ['Storage.File.Delete', 'Storage.Directory.Delete']:
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', 'Deletes the entry in the external storage. The delete happens outside the Business Central transaction and cannot be undone.');
                end;
            MessageType = 'Storage.Attachment.Restore':
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', 'Writes the content back into the Business Central attachment, then deletes the offloaded file in the external storage. The delete happens outside the Business Central transaction and cannot be undone.');
                end;
            MessageType = 'Storage.Attachment.Offload':
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', 'Links the Business Central attachment to the external file and clears its local content, then writes the file to the external storage. The external write happens outside the Business Central transaction and is not rolled back with it.');
                end;
            MessageType = 'Storage.Upload.Commit':
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', 'Assembles the staged chunks and writes the file to the external storage. The external write happens outside the Business Central transaction and is not rolled back with it.');
                end;
            MessageType in ['Storage.File.Create', 'Storage.File.Copy', 'Storage.File.Move', 'Storage.Directory.Create']:
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', 'Writes to the external storage. The external write happens outside the Business Central transaction and is not rolled back with it.');
                end;
            MessageType in ['Storage.Attachment.CreateLinked', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.Begin', 'Storage.Upload.Append', 'Storage.Upload.Abort', 'Storage.Upload.CommitToRecord']:
                begin
                    Effect.Add('effect', 'write');
                    Effect.Add('changes', 'Writes Business Central records only (upload session, chunks or document attachments) inside the caller''s transaction; the external storage is not changed.');
                end;
            else begin
                Effect.Add('effect', 'read');
                Effect.Add('changes', 'Reads only; nothing is changed.');
            end;
        end;
        Effect.Add('idempotent', MessageType in ['Storage.Account.List', 'Storage.File.List', 'Storage.File.Get', 'Storage.File.Exists', 'Storage.Directory.List', 'Storage.Directory.Exists', 'Storage.Upload.Status', 'DataExchange.Definition.List', 'DataExchange.Definition.Get', 'DataExchange.Type.List', 'DataExchange.Entry.List', 'DataExchange.Entry.Get']);
        Effect.Add('permissionSet', 'BIFROST Attach ori');
        if MessageType.StartsWith('DataExchange.') then
            Effect.Add('preconditions', DataExchangePreconditionsLbl)
        else
            Effect.Add('preconditions', 'The storage connection exists, is enabled and permits the requested operation.');
    end;

    /// <summary>Builds related message types for one message type.</summary>
    procedure GetRelated(MessageType: Text) Related: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'Help.Storage.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Account.List', 'Choose a configured storage connection.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.List', 'List files in a storage connection.'));
                end;
            'Help.DataExchange.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', 'Discover available Data Exchange definitions.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.List', 'List processed Data Exchange entries.'));
                end;
            'Storage.Account.List':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.List', 'List files after choosing a storageCode.'));
            'Storage.File.List':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Directory.List', 'List subdirectories instead of files.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Get', 'Download one listed file.'));
                end;
            'Storage.File.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Exists', 'Check whether a file exists without downloading it.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Create', 'Upload a file instead of downloading it.'));
                end;
            'Storage.File.Create':
                Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Begin', 'Upload a file larger than the single-call limit.'));
            'Storage.File.Delete':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Exists', 'Check whether the file exists first.'));
            'Storage.File.Copy':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Move', 'Move the file and remove the original path.'));
            'Storage.File.Move':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Copy', 'Copy the file while keeping the original.'));
            'Storage.Directory.List':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.List', 'List files instead of subdirectories.'));
            'Storage.Directory.Create':
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.Delete', 'Remove a directory.'));
            'Storage.Directory.Delete':
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.Exists', 'Check whether the directory exists first.'));
            'Storage.Directory.Exists':
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.List', 'List the directory contents.'));
            'Storage.Attachment.Offload':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Restore', 'Bring the file back into the database.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Account.List', 'Find a storageCode.'));
                end;
            'Storage.Attachment.Restore':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Offload', 'Move the file back to storage.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.CreateLinked', 'Create a new linked attachment.'));
                end;
            'Storage.Attachment.CreateLinked':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', 'Use the path of a committed upload.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Restore', 'Bring the linked file into the database.'));
                end;
            'Storage.Attachment.CreateForRecord':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.CommitToRecord', 'Attach a chunked upload directly to a record.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Offload', 'Move inline content to storage later.'));
                end;
            'Storage.Upload.Begin':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Append', 'Send each chunk.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', 'Write the completed file to storage.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.CommitToRecord', 'Attach the completed file without storage.'));
                end;
            'Storage.Upload.Append':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Status', 'Check received bytes.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', 'Commit the completed upload.'));
                end;
            'Storage.Upload.Commit':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Get', 'Download the committed file.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.CreateLinked', 'Attach the committed file.'));
                end;
            'Storage.Upload.Abort':
                Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Begin', 'Start a fresh upload.'));
            'Storage.Upload.Status':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Append', 'Send another chunk.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', 'Commit when complete.'));
                end;
            'Storage.Upload.CommitToRecord':
                Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Offload', 'Move the created attachment to storage later.'));
            'DataExchange.Definition.List':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Get', 'Read one definition in full.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Type.List', 'See which type uses a definition.'));
                end;
            'DataExchange.Definition.Get':
                Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', 'Find another definition code.'));
            'DataExchange.Type.List':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', 'List available definitions.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Get', 'Read the referenced definition.'));
                end;
            'DataExchange.Entry.List':
                Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.Get', 'Read one entry and its fields.'));
            'DataExchange.Entry.Get':
                Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.List', 'Find another entry.'));
        end;
    end;
}