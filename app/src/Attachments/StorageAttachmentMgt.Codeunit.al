namespace Origo.Bifrost.Attachments;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using System.DataAdministration;
using System.Reflection;
using System.Text;
using System.Utilities;

/// <summary>
/// Moves attachment file content between the Business Central database and external storage.
/// Offload reads the current content, uploads it through the configured <c>Bifrost Storage
/// Connector</c>, records a <c>Bifrost Storage Attachment Link</c> row and clears the local
/// content. Restore fetches the content back, writes it into the record, deletes the remote
/// copy and removes the link. The same connector helpers serve content transparently to the
/// table read hooks (see <see cref="Codeunit.StorageAttachmentSubscr"/>).
/// </summary>
codeunit 10035635 "Storage Attachment Mgt ori"
{
    Access = Internal;

    var
        BasePathTok: Label 'bifrost-attachments', Locked = true;
        IncDocPathWithYearTok: Label '%1/incoming-documents/%2/%3/%4', Comment = '%1 = base path, %2 = year, %3 = entry no., %4 = file name', Locked = true;
        IncDocPathTok: Label '%1/incoming-documents/%2/%3', Comment = '%1 = base path, %2 = entry no., %3 = file name', Locked = true;
        MissingParamErr: Label 'Missing required ''%1'' in the request.', Comment = '%1 = parameter name', Locked = true;
        UnknownTargetErr: Label 'Unknown attachment target ''%1''. Use ''IncomingDocument'' or ''DocumentAttachment''.', Comment = '%1 = target', Locked = true;
        InvalidSystemIdErr: Label '''%1'' is not a valid SystemId.', Comment = '%1 = system id text', Locked = true;
        UnknownCodeErr: Label 'No storage connection is configured for storageCode ''%1''.', Comment = '%1 = storage code', Locked = true;
        DisabledCodeErr: Label 'The storage connection ''%1'' is disabled.', Comment = '%1 = storage code', Locked = true;
        RecordNotFoundErr: Label 'No attachment record was found for the supplied SystemId.', Locked = true;
        NoContentErr: Label 'The attachment has no content to offload.', Locked = true;
        AlreadyOffloadedErr: Label 'The attachment is already offloaded. Restore it before offloading again.', Locked = true;
        NotOffloadedErr: Label 'The attachment is not offloaded.', Locked = true;
        NoStorageFileErr: Label 'No file was found in storage at ''%1''.', Comment = '%1 = storage path', Locked = true;
        IncDocNotFoundErr: Label 'No incoming document was found with entry no. %1.', Comment = '%1 = entry no.', Locked = true;
        LinkedFileDeleteErr: Label 'File ''%1'' is linked to a Business Central attachment and cannot be deleted directly from storage.', Comment = '%1 = storage path', Locked = true;
        LinkedDirectoryDeleteErr: Label 'Directory ''%1'' contains one or more files linked to Business Central attachments and cannot be deleted directly from storage.', Comment = '%1 = directory path', Locked = true;
        LinkPermissionErr: Label 'You do not have permission to update Bifrost Storage attachment links.', Locked = true;
        TargetPermissionErr: Label 'You do not have permission to update linked Business Central table %1.', Comment = '%1 = table id', Locked = true;
        UnknownTableErr: Label 'Table %1 does not exist.', Comment = '%1 = table id', Locked = true;
        UnknownTableNameErr: Label 'No table named ''%1'' exists.', Comment = '%1 = table name', Locked = true;
        NoRecordErr: Label 'No record was found in table %1 for the supplied key.', Comment = '%1 = table id', Locked = true;
        CompositeKeyErr: Label 'Table %1 has a composite primary key, so it cannot be addressed with ''no''. Use ''recordSystemId'' instead.', Comment = '%1 = table id', Locked = true;
        NonCodeKeyErr: Label 'The primary key of table %1 is not a code or text field, so it cannot be addressed with ''no''. Use ''recordSystemId'' instead.', Comment = '%1 = table id', Locked = true;
        RecordNoTooLongErr: Label 'The record identifier ''%1'' is longer than the 20 characters a document attachment can hold.', Comment = '%1 = record identifier', Locked = true;
        ContentSourceErr: Label 'Supply exactly one content source: ''content'', ''storageCode'' with ''path'', or ''sourceTarget'' with ''sourceSystemId''.', Locked = true;
        NoAttachmentKeyErr: Label 'Business Central does not know which field identifies a record in table %1, so an attachment cannot be keyed to it. Subscribe to Document Attachment Mgmt.OnAfterTableHasNumberFieldPrimaryKey for that table.', Comment = '%1 = table id', Locked = true;
        PathAlreadyLinkedErr: Label 'The storage path ''%1'' on connection ''%2'' is already linked to another attachment. Each storage file can only back one attachment.', Comment = '%1 = storage path, %2 = storage code', Locked = true;

    /// <summary>Offloads an attachment's content to storage and clears it from the database.</summary>
    /// <param name="RequestJson">Request carrying <c>target</c>, <c>systemId</c> and <c>storageCode</c>.</param>
    /// <param name="ResultData">Out: the success payload describing the offloaded file.</param>
    procedure Offload(RequestJson: JsonObject; var ResultData: JsonObject)
    var
        StorageSetup: Record "Storage Setup ori";
        Link: Record "Storage Attachment Link ori";
        TempBlob: Codeunit "Temp Blob";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        Target: Enum "Storage Attachment Target ori";
        RecSystemId: Guid;
        StorageCode: Code[20];
        TableId: Integer;
        EntryNo: Integer;
        LineNo: Integer;
        FileName: Text;
        FolderPath: Text;
        Path: Text;
    begin
        Target := ParseTarget(RequestJson);
        RecSystemId := ParseSystemId(RequestJson);
        StorageCode := CopyStr(RequireText(RequestJson, 'storageCode'), 1, MaxStrLen(StorageCode));
        FolderPath := RequestMgt.GetText(RequestJson, 'folderPath');
        GetConnector(StorageCode, StorageSetup, Connector);
        TableId := TableIdForTarget(Target);

        if Link.Get(TableId, RecSystemId) then
            Error(AlreadyOffloadedErr);

        ReadAttachment(Target, RecSystemId, TempBlob, FileName, EntryNo, LineNo);
        if not TempBlob.HasValue() then
            Error(NoContentErr);

        Path := BuildPath(Target, TableId, RecSystemId, FileName, EntryNo, FolderPath);

        // The database writes happen first, then the upload last. The upload is the only step that
        // is not part of the transaction, so any failure before it rolls back cleanly (nothing
        // uploaded), and a failed upload rolls back the link insert and the content clear with it —
        // leaving no orphan blob in storage and the attachment content intact.
        Link.Init();
        Link."Table ID" := TableId;
        Link."Record System Id" := RecSystemId;
        Link."Storage Code" := StorageCode;
        Link."Storage Path" := CopyStr(Path, 1, MaxStrLen(Link."Storage Path"));
        Link."File Name" := CopyStr(FileName, 1, MaxStrLen(Link."File Name"));
        Link."Content Size" := TempBlob.Length();
        Link."Inc. Doc. Entry No." := EntryNo;
        Link."Inc. Doc. Line No." := LineNo;
        Link."Offloaded At" := CurrentDateTime();
        Link."Offloaded By" := UserSecurityId();
        Link.Insert(true);

        ClearAttachment(Target, RecSystemId);

        Connector.CreateFile(StorageSetup, Path, TempBlob);

        if TaskScheduler.CanCreateTask() then
            TaskScheduler.CreateTask(Codeunit::"Media Cleanup Runner", 0, true, CompanyName, CurrentDateTime() + 5000);

        ResultData.Add('target', TargetName(Target));
        ResultData.Add('systemId', Format(RecSystemId, 0, 4));
        ResultData.Add('storageCode', StorageCode);
        ResultData.Add('path', Path);
        ResultData.Add('contentLength', Link."Content Size");
    end;

    /// <summary>Restores an offloaded attachment's content into the database and deletes the remote copy.</summary>
    /// <param name="RequestJson">Request carrying <c>target</c> and <c>systemId</c>.</param>
    /// <param name="ResultData">Out: the success payload describing the restored file.</param>
    procedure Restore(RequestJson: JsonObject; var ResultData: JsonObject)
    var
        StorageSetup: Record "Storage Setup ori";
        Link: Record "Storage Attachment Link ori";
        TempBlob: Codeunit "Temp Blob";
        Connector: Interface "Storage Connector ori";
        Target: Enum "Storage Attachment Target ori";
        RecSystemId: Guid;
        TableId: Integer;
    begin
        Target := ParseTarget(RequestJson);
        RecSystemId := ParseSystemId(RequestJson);
        TableId := TableIdForTarget(Target);

        Link.SetLoadFields("Storage Code", "Storage Path", "File Name");
        if not Link.Get(TableId, RecSystemId) then
            Error(NotOffloadedErr);

        GetConnector(Link."Storage Code", StorageSetup, Connector);
        Connector.GetFile(StorageSetup, Link."Storage Path", TempBlob);
        WriteAttachment(Target, RecSystemId, TempBlob, Link."File Name");

        ResultData.Add('target', TargetName(Target));
        ResultData.Add('systemId', Format(RecSystemId, 0, 4));
        ResultData.Add('contentLength', TempBlob.Length());

        // Same discipline as Offload: every database write happens first and the irreversible
        // remote step last. Deleting the remote copy before the link row is removed would, on any
        // later failure, roll the database back to the offloaded state with the only copy of the
        // file already gone. In this order a failing delete rolls the whole task back instead —
        // the attachment stays offloaded and its remote copy stays where the link says it is.
        Link.Delete(true);
        Connector.DeleteFile(StorageSetup, Link."Storage Path");
    end;

    /// <summary>
    /// Creates an incoming-document attachment that points at a file already in storage (typically
    /// delivered through the chunked-upload message types). The attachment is created from the
    /// stored content, immediately linked, then its local content is cleared — so it ends up in the
    /// same transparently-served, born-offloaded state as <see cref="Offload"/> produces, without
    /// the file ever passing through the database from the caller.
    /// </summary>
    /// <param name="RequestJson">Request carrying <c>storageCode</c>, <c>path</c>, <c>fileName</c> and optional <c>incomingDocumentEntryNo</c>/<c>description</c>.</param>
    /// <param name="ResultData">Out: the success payload describing the new linked attachment.</param>
    procedure CreateLinked(RequestJson: JsonObject; var ResultData: JsonObject)
    var
        StorageSetup: Record "Storage Setup ori";
        IncomingDocument: Record "Incoming Document";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
        Link: Record "Storage Attachment Link ori";
        TempBlob: Codeunit "Temp Blob";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        ContentInStream: InStream;
        StorageCode: Code[20];
        StoragePath: Text;
        FileName: Text;
        Description: Text;
        Extension: Text;
        EntryNo: Integer;
    begin
        StorageCode := CopyStr(RequireText(RequestJson, 'storageCode'), 1, MaxStrLen(StorageCode));
        StoragePath := RequireText(RequestJson, 'path');
        FileName := RequireText(RequestJson, 'fileName');
        Description := RequestMgt.GetText(RequestJson, 'description');
        EntryNo := GetOptionalInteger(RequestJson, 'incomingDocumentEntryNo');

        GetConnector(StorageCode, StorageSetup, Connector);
        Connector.GetFile(StorageSetup, StoragePath, TempBlob);
        if not TempBlob.HasValue() then
            Error(NoStorageFileErr, StoragePath);
        AssertPathNotLinked(StorageCode, StoragePath);

        if EntryNo = 0 then begin
            if Description = '' then
                Description := FileName;
            EntryNo := IncomingDocument.CreateIncomingDocument(CopyStr(Description, 1, 100), '');
        end;
        if not IncomingDocument.Get(EntryNo) then
            Error(IncDocNotFoundErr, EntryNo);

        Extension := FileExtensionOf(FileName);
        TempBlob.CreateInStream(ContentInStream);
        IncomingDocument.AddAttachmentFromStream(IncomingDocumentAttachment, FileName, Extension, ContentInStream);

        Link.Init();
        Link."Table ID" := Database::"Incoming Document Attachment";
        Link."Record System Id" := IncomingDocumentAttachment.SystemId;
        Link."Storage Code" := StorageCode;
        Link."Storage Path" := CopyStr(StoragePath, 1, MaxStrLen(Link."Storage Path"));
        Link."File Name" := CopyStr(FileName, 1, MaxStrLen(Link."File Name"));
        Link."Content Size" := TempBlob.Length();
        Link."Inc. Doc. Entry No." := IncomingDocumentAttachment."Incoming Document Entry No.";
        Link."Inc. Doc. Line No." := IncomingDocumentAttachment."Line No.";
        Link."Offloaded At" := CurrentDateTime();
        Link."Offloaded By" := UserSecurityId();
        Link.Insert(true);

        Clear(IncomingDocumentAttachment.Content);
        IncomingDocumentAttachment.Modify(true);

        ResultData.Add('target', 'IncomingDocument');
        ResultData.Add('incomingDocumentEntryNo', IncomingDocumentAttachment."Incoming Document Entry No.");
        ResultData.Add('lineNo', IncomingDocumentAttachment."Line No.");
        ResultData.Add('systemId', Format(IncomingDocumentAttachment.SystemId, 0, 4));
        ResultData.Add('storageCode', StorageCode);
        ResultData.Add('path', StoragePath);
        ResultData.Add('fileName', FileName);
        ResultData.Add('contentLength', Link."Content Size");
    end;

    /// <summary>
    /// Creates a <c>Document Attachment</c> on any Business Central record — a customer, a vendor,
    /// a fixed asset, a posted document — from one of three content sources: inline base64, a file
    /// already sitting in storage, or an attachment that already exists somewhere else in Business
    /// Central. When the source is a storage file the attachment is born offloaded: it is linked to
    /// the stored file and its local content is cleared, the same end state <see cref="CreateLinked"/>
    /// produces for incoming documents. The other two sources keep the content in the database.
    /// </summary>
    /// <remarks>
    /// The row is written through the base application's own <c>SaveAttachmentFromStream</c>, which
    /// fills the attachment key from the record, gives the file a name that is unique within that
    /// record, imports the content and inserts — in that order, because <c>Document Attachment</c>'s
    /// insert trigger rejects a row that has no file yet. Which tables it can key is decided by
    /// <c>Document Attachment Mgmt</c>; see <see cref="Codeunit.StorageAttachKeySubscr"/> for the
    /// subscriber that widens that set to every table with a single code primary key.
    /// </remarks>
    /// <param name="RequestJson">Request carrying the record address, <c>fileName</c> and one content source.</param>
    /// <param name="ResultData">Out: the success payload describing the new attachment.</param>
    procedure CreateForRecord(RequestJson: JsonObject; var ResultData: JsonObject)
    var
        DocumentAttachment: Record "Document Attachment";
        Link: Record "Storage Attachment Link ori";
        TempBlob: Codeunit "Temp Blob";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        RecordRef: RecordRef;
        FromStorage: Boolean;
        StorageCode: Code[20];
        TableId: Integer;
        ContentInStream: InStream;
        FileName: Text;
        SourceFileName: Text;
        StoragePath: Text;
    begin
        TableId := ResolveTableId(RequestJson);
        ResolveRecord(RequestJson, TableId, RecordRef);

        LoadRequestedContent(RequestJson, TempBlob, StorageCode, StoragePath, SourceFileName, FromStorage);

        if FromStorage then
            AssertPathNotLinked(StorageCode, StoragePath);

        // fileName is optional only when copying an attachment that already carries one.
        FileName := RequestMgt.GetText(RequestJson, 'fileName');
        if FileName = '' then
            FileName := SourceFileName;
        if FileName = '' then
            Error(MissingParamErr, 'fileName');

        TempBlob.CreateInStream(ContentInStream);
        DocumentAttachment.Init();
        DocumentAttachment.SaveAttachmentFromStream(ContentInStream, RecordRef, FileName);
        RecordRef.Close();

        // An empty key means the base application could not tell which field identifies the record.
        // Raising here rolls the insert back with the whole message.
        if DocumentAttachment."No." = '' then
            Error(NoAttachmentKeyErr, TableId);

        if FromStorage then begin
            Link.Init();
            Link."Table ID" := Database::"Document Attachment";
            Link."Record System Id" := DocumentAttachment.SystemId;
            Link."Storage Code" := StorageCode;
            Link."Storage Path" := CopyStr(StoragePath, 1, MaxStrLen(Link."Storage Path"));
            Link."File Name" := CopyStr(FileName, 1, MaxStrLen(Link."File Name"));
            Link."Content Size" := TempBlob.Length();
            Link."Offloaded At" := CurrentDateTime();
            Link."Offloaded By" := UserSecurityId();
            Link.Insert(true);

            Clear(DocumentAttachment."Document Reference ID");
            DocumentAttachment.Modify(true);
        end;

        ResultData.Add('target', 'DocumentAttachment');
        ResultData.Add('tableId', DocumentAttachment."Table ID");
        ResultData.Add('no', DocumentAttachment."No.");
        ResultData.Add('documentType', Format(DocumentAttachment."Document Type", 0, 9));
        ResultData.Add('lineNo', DocumentAttachment."Line No.");
        ResultData.Add('attachmentId', DocumentAttachment.ID);
        ResultData.Add('systemId', Format(DocumentAttachment.SystemId, 0, 4));
        ResultData.Add('fileName', ComposeFileName(DocumentAttachment."File Name", DocumentAttachment."File Extension"));
        ResultData.Add('contentLength', TempBlob.Length());
        ResultData.Add('offloaded', FromStorage);
        if FromStorage then begin
            ResultData.Add('storageCode', StorageCode);
            ResultData.Add('path', StoragePath);
        end;
    end;

    /// <summary>Creates a document attachment from pre-assembled content (used by CommitToRecord).</summary>
    procedure CreateForRecordFromBlob(RequestJson: JsonObject; var TempBlob: Codeunit "Temp Blob"; SessionFileName: Text; var ResultData: JsonObject)
    var
        DocumentAttachment: Record "Document Attachment";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        RecordRef: RecordRef;
        TableId: Integer;
        ContentInStream: InStream;
        FileName: Text;
    begin
        TableId := ResolveTableId(RequestJson);
        ResolveRecord(RequestJson, TableId, RecordRef);

        FileName := RequestMgt.GetText(RequestJson, 'fileName');
        if FileName = '' then
            FileName := SessionFileName;
        if FileName = '' then
            Error(MissingParamErr, 'fileName');

        TempBlob.CreateInStream(ContentInStream);
        DocumentAttachment.Init();
        DocumentAttachment.SaveAttachmentFromStream(ContentInStream, RecordRef, FileName);
        RecordRef.Close();

        if DocumentAttachment."No." = '' then
            Error(NoAttachmentKeyErr, TableId);

        ResultData.Add('target', 'DocumentAttachment');
        ResultData.Add('tableId', DocumentAttachment."Table ID");
        ResultData.Add('no', DocumentAttachment."No.");
        ResultData.Add('documentType', Format(DocumentAttachment."Document Type", 0, 9));
        ResultData.Add('lineNo', DocumentAttachment."Line No.");
        ResultData.Add('attachmentId', DocumentAttachment.ID);
        ResultData.Add('systemId', Format(DocumentAttachment.SystemId, 0, 4));
        ResultData.Add('fileName', ComposeFileName(DocumentAttachment."File Name", DocumentAttachment."File Extension"));
        ResultData.Add('contentLength', TempBlob.Length());
        ResultData.Add('offloaded', false);
    end;

    /// <summary>Creates an incoming document attachment from pre-assembled content (used by CommitToRecord).</summary>
    procedure CreateIncomingFromBlob(RequestJson: JsonObject; var TempBlob: Codeunit "Temp Blob"; SessionFileName: Text; var ResultData: JsonObject)
    var
        IncomingDocument: Record "Incoming Document";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ContentInStream: InStream;
        FileName: Text;
        Description: Text;
        Extension: Text;
        EntryNo: Integer;
    begin
        FileName := RequestMgt.GetText(RequestJson, 'fileName');
        if FileName = '' then
            FileName := SessionFileName;
        if FileName = '' then
            Error(MissingParamErr, 'fileName');
        Description := RequestMgt.GetText(RequestJson, 'description');
        EntryNo := GetOptionalInteger(RequestJson, 'incomingDocumentEntryNo');

        if EntryNo = 0 then begin
            if Description = '' then
                Description := FileName;
            EntryNo := IncomingDocument.CreateIncomingDocument(CopyStr(Description, 1, 100), '');
        end;
        if not IncomingDocument.Get(EntryNo) then
            Error(IncDocNotFoundErr, EntryNo);

        Extension := FileExtensionOf(FileName);
        TempBlob.CreateInStream(ContentInStream);
        IncomingDocument.AddAttachmentFromStream(IncomingDocumentAttachment, FileName, Extension, ContentInStream);

        ResultData.Add('target', 'IncomingDocument');
        ResultData.Add('incomingDocumentEntryNo', IncomingDocumentAttachment."Incoming Document Entry No.");
        ResultData.Add('lineNo', IncomingDocumentAttachment."Line No.");
        ResultData.Add('systemId', Format(IncomingDocumentAttachment.SystemId, 0, 4));
        ResultData.Add('fileName', FileName);
        ResultData.Add('contentLength', TempBlob.Length());
        ResultData.Add('offloaded', false);
    end;

    local procedure ResolveTableId(RequestJson: JsonObject) TableId: Integer
    var
        AllObjWithCaption: Record AllObjWithCaption;
        RequestMgt: Codeunit "Storage Request Mgt ori";
        TableName: Text;
    begin
        TableId := GetOptionalInteger(RequestJson, 'tableId');
        if TableId <> 0 then
            exit(TableId);

        TableName := RequestMgt.GetText(RequestJson, 'tableName');
        if TableName = '' then
            Error(MissingParamErr, 'tableId');

        AllObjWithCaption.SetRange("Object Type", AllObjWithCaption."Object Type"::Table);
        AllObjWithCaption.SetRange("Object Name", CopyStr(TableName, 1, MaxStrLen(AllObjWithCaption."Object Name")));
        if not AllObjWithCaption.FindFirst() then
            Error(UnknownTableNameErr, TableName);
        exit(AllObjWithCaption."Object ID");
    end;

    /// <summary>
    /// Opens the host table and positions the reference on the record the attachment belongs to.
    /// <c>recordSystemId</c> works for every table; <c>no</c> is the convenience path for master
    /// records, whose primary key is one code field.
    /// </summary>
    local procedure ResolveRecord(RequestJson: JsonObject; TableId: Integer; var RecordRef: RecordRef)
    var
        AllObjWithCaption: Record AllObjWithCaption;
        RequestMgt: Codeunit "Storage Request Mgt ori";
        FieldRef: FieldRef;
        KeyRef: KeyRef;
        RecSystemId: Guid;
        AttachmentNo: Code[20];
        NoText: Text;
        SystemIdText: Text;
    begin
        if not AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Table, TableId) then
            Error(UnknownTableErr, TableId);

        RecordRef.Open(TableId);
        if not RecordRef.ReadPermission() then
            Error(TargetPermissionErr, TableId);

        SystemIdText := RequestMgt.GetText(RequestJson, 'recordSystemId');
        if SystemIdText <> '' then begin
            if not Evaluate(RecSystemId, SystemIdText) then
                Error(InvalidSystemIdErr, SystemIdText);
            if not RecordRef.GetBySystemId(RecSystemId) then
                Error(NoRecordErr, TableId);
            exit;
        end;

        NoText := RequestMgt.GetText(RequestJson, 'no');
        if NoText = '' then
            Error(MissingParamErr, 'no');
        // Document Attachment's own key is a Code[20], so a longer identifier can never be stored.
        if StrLen(NoText) > MaxStrLen(AttachmentNo) then
            Error(RecordNoTooLongErr, NoText);

        KeyRef := RecordRef.KeyIndex(1);
        if KeyRef.FieldCount() <> 1 then
            Error(CompositeKeyErr, TableId);
        FieldRef := KeyRef.FieldIndex(1);
        if not (FieldRef.Type() in [FieldType::Code, FieldType::Text]) then
            Error(NonCodeKeyErr, TableId);

        FieldRef.Value := NoText;
        if not RecordRef.Find('=') then
            Error(NoRecordErr, TableId);
    end;

    /// <summary>Resolves exactly one of the three content sources into <paramref name="TempBlob"/>.</summary>
    local procedure LoadRequestedContent(RequestJson: JsonObject; var TempBlob: Codeunit "Temp Blob"; var StorageCode: Code[20]; var StoragePath: Text; var SourceFileName: Text; var FromStorage: Boolean)
    var
        StorageSetup: Record "Storage Setup ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        SourceTarget: Enum "Storage Attachment Target ori";
        SourceSystemId: Guid;
        SourceCount: Integer;
        SourceEntryNo: Integer;
        SourceLineNo: Integer;
        ContentOutStream: OutStream;
        ContentBase64: Text;
        SourceSystemIdText: Text;
    begin
        Clear(TempBlob);
        FromStorage := false;
        SourceFileName := '';

        ContentBase64 := RequestMgt.GetText(RequestJson, 'content');
        StorageCode := CopyStr(RequestMgt.GetText(RequestJson, 'storageCode'), 1, MaxStrLen(StorageCode));
        StoragePath := RequestMgt.GetText(RequestJson, 'path');
        SourceSystemIdText := RequestMgt.GetText(RequestJson, 'sourceSystemId');

        if ContentBase64 <> '' then
            SourceCount += 1;
        if (StorageCode <> '') or (StoragePath <> '') then
            SourceCount += 1;
        if SourceSystemIdText <> '' then
            SourceCount += 1;
        if SourceCount <> 1 then
            Error(ContentSourceErr);

        if ContentBase64 <> '' then begin
            TempBlob.CreateOutStream(ContentOutStream);
            Base64Convert.FromBase64(ContentBase64, ContentOutStream);
            exit;
        end;

        if SourceSystemIdText <> '' then begin
            SourceTarget := ParseTargetProperty(RequestJson, 'sourceTarget');
            if not Evaluate(SourceSystemId, SourceSystemIdText) then
                Error(InvalidSystemIdErr, SourceSystemIdText);
            // Reads through the transparent serve hooks, so a source that is itself offloaded works.
            ReadAttachment(SourceTarget, SourceSystemId, TempBlob, SourceFileName, SourceEntryNo, SourceLineNo);
            if not TempBlob.HasValue() then
                Error(NoContentErr);
            exit;
        end;

        if StorageCode = '' then
            Error(MissingParamErr, 'storageCode');
        if StoragePath = '' then
            Error(MissingParamErr, 'path');
        GetConnector(StorageCode, StorageSetup, Connector);
        Connector.GetFile(StorageSetup, StoragePath, TempBlob);
        if not TempBlob.HasValue() then
            Error(NoStorageFileErr, StoragePath);
        FromStorage := true;
    end;

    /// <summary>Fetches offloaded content from storage. Used by the transparent read hooks.</summary>
    /// <param name="StorageCode">The storage connection that holds the content.</param>
    /// <param name="Path">The path of the offloaded file.</param>
    /// <param name="TempBlob">Out: the fetched content.</param>
    procedure FetchContent(StorageCode: Code[20]; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        StorageSetup: Record "Storage Setup ori";
        Connector: Interface "Storage Connector ori";
    begin
        GetConnector(StorageCode, StorageSetup, Connector);
        Connector.GetFile(StorageSetup, Path, TempBlob);
    end;

    /// <summary>Deletes an offloaded file from storage. Used by attachment delete cleanup.</summary>
    /// <param name="StorageCode">The storage connection that holds the content.</param>
    /// <param name="Path">The path of the offloaded file.</param>
    procedure DeleteRemote(StorageCode: Code[20]; Path: Text)
    var
        StorageSetup: Record "Storage Setup ori";
        Connector: Interface "Storage Connector ori";
    begin
        GetConnector(StorageCode, StorageSetup, Connector);
        Connector.DeleteFile(StorageSetup, Path);
    end;

    /// <summary>Blocks direct file deletion when the file is tracked by an attachment link.</summary>
    /// <param name="StorageCode">The storage connection that holds the file.</param>
    /// <param name="Path">The storage path about to be deleted.</param>
    procedure AssertCanDeleteStorageFile(StorageCode: Code[20]; Path: Text)
    var
        Link: Record "Storage Attachment Link ori";
    begin
        if FindLinkedStorageFile(StorageCode, Path, Link) then
            Error(LinkedFileDeleteErr, Path);
    end;

    /// <summary>Blocks direct directory deletion when any linked attachment file is inside it.</summary>
    /// <param name="StorageCode">The storage connection that holds the directory.</param>
    /// <param name="DirectoryPath">The storage directory about to be deleted.</param>
    procedure AssertCanDeleteStorageDirectory(StorageCode: Code[20]; DirectoryPath: Text)
    var
        Link: Record "Storage Attachment Link ori";
    begin
        if FindLinkedStoragePathInDirectory(StorageCode, DirectoryPath, Link) then
            Error(LinkedDirectoryDeleteErr, DirectoryPath);
    end;

    /// <summary>Verifies that a linked file can be moved and its link rows can be updated.</summary>
    /// <param name="StorageCode">The storage connection that holds the file.</param>
    /// <param name="SourcePath">The current storage path.</param>
    procedure AssertCanMoveStorageFile(StorageCode: Code[20]; SourcePath: Text)
    var
        Link: Record "Storage Attachment Link ori";
    begin
        if not FindLinkedStorageFile(StorageCode, SourcePath, Link) then
            exit;
        repeat
            AssertCanUpdateLink(Link);
        until Link.Next() = 0;
    end;

    /// <summary>Updates attachment link rows after a linked storage file is moved.</summary>
    /// <param name="StorageCode">The storage connection that holds the file.</param>
    /// <param name="SourcePath">The previous storage path.</param>
    /// <param name="TargetPath">The new storage path.</param>
    procedure UpdateMovedStorageFile(StorageCode: Code[20]; SourcePath: Text; TargetPath: Text)
    var
        Link: Record "Storage Attachment Link ori";
    begin
        Link.ReadIsolation := IsolationLevel::UpdLock;
        if not FindLinkedStorageFile(StorageCode, SourcePath, Link) then
            exit;
        repeat
            Link."Storage Path" := CopyStr(TargetPath, 1, MaxStrLen(Link."Storage Path"));
            Link.Modify(true);
        until Link.Next() = 0;
    end;

    /// <summary>Returns the table id that an attachment target maps to.</summary>
    /// <param name="Target">The attachment target.</param>
    /// <returns>The Business Central table id.</returns>
    procedure TableIdForTarget(Target: Enum "Storage Attachment Target ori"): Integer
    begin
        case Target of
            Target::DocumentAttachment:
                exit(Database::"Document Attachment");
            Target::IncomingDocument:
                exit(Database::"Incoming Document Attachment");
        end;
    end;

    local procedure AssertPathNotLinked(StorageCode: Code[20]; Path: Text)
    var
        Link: Record "Storage Attachment Link ori";
    begin
        if FindLinkedStorageFile(StorageCode, Path, Link) then
            Error(PathAlreadyLinkedErr, Path, StorageCode);
    end;

    local procedure FindLinkedStorageFile(StorageCode: Code[20]; Path: Text; var Link: Record "Storage Attachment Link ori"): Boolean
    begin
        Link.Reset();
        Link.SetCurrentKey("Storage Code", "Storage Path");
        Link.SetRange("Storage Code", StorageCode);
        Link.SetRange("Storage Path", Path);
        exit(Link.FindSet(true));
    end;

    local procedure FindLinkedStoragePathInDirectory(StorageCode: Code[20]; DirectoryPath: Text; var Link: Record "Storage Attachment Link ori"): Boolean
    begin
        Link.Reset();
        Link.SetCurrentKey("Storage Code", "Storage Path");
        Link.SetRange("Storage Code", StorageCode);
        if Link.FindSet(true) then
            repeat
                if StoragePathIsInDirectory(Link."Storage Path", DirectoryPath) then
                    exit(true);
            until Link.Next() = 0;
    end;

    local procedure StoragePathIsInDirectory(StoragePath: Text; DirectoryPath: Text): Boolean
    begin
        if DirectoryPath = '' then
            exit(StoragePath <> '');
        if StoragePath = DirectoryPath then
            exit(true);
        exit(StoragePath.StartsWith(DirectoryPath + '/'));
    end;

    local procedure AssertCanUpdateLink(var Link: Record "Storage Attachment Link ori")
    var
        LinkedRecordRef: RecordRef;
    begin
        if not Link.WritePermission() then
            Error(LinkPermissionErr);
        LinkedRecordRef.Open(Link."Table ID");
        if not LinkedRecordRef.WritePermission() then
            Error(TargetPermissionErr, Link."Table ID");
        LinkedRecordRef.Close();
    end;

    local procedure ReadAttachment(Target: Enum "Storage Attachment Target ori"; RecSystemId: Guid; var TempBlob: Codeunit "Temp Blob"; var FileName: Text; var EntryNo: Integer; var LineNo: Integer)
    var
        DocumentAttachment: Record "Document Attachment";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
    begin
        EntryNo := 0;
        LineNo := 0;
        case Target of
            Target::DocumentAttachment:
                begin
                    if not DocumentAttachment.GetBySystemId(RecSystemId) then
                        Error(RecordNotFoundErr);
                    FileName := ComposeFileName(DocumentAttachment."File Name", DocumentAttachment."File Extension");
                    DocumentAttachment.GetAsTempBlob(TempBlob);
                end;
            Target::IncomingDocument:
                begin
                    if not IncomingDocumentAttachment.GetBySystemId(RecSystemId) then
                        Error(RecordNotFoundErr);
                    FileName := ComposeFileName(IncomingDocumentAttachment.Name, IncomingDocumentAttachment."File Extension");
                    EntryNo := IncomingDocumentAttachment."Incoming Document Entry No.";
                    LineNo := IncomingDocumentAttachment."Line No.";
                    IncomingDocumentAttachment.GetContent(TempBlob);
                end;
        end;
    end;

    local procedure ClearAttachment(Target: Enum "Storage Attachment Target ori"; RecSystemId: Guid)
    var
        DocumentAttachment: Record "Document Attachment";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
    begin
        case Target of
            Target::DocumentAttachment:
                begin
                    if not DocumentAttachment.GetBySystemId(RecSystemId) then
                        Error(RecordNotFoundErr);
                    Clear(DocumentAttachment."Document Reference ID");
                    DocumentAttachment.Modify(true);
                end;
            Target::IncomingDocument:
                begin
                    if not IncomingDocumentAttachment.GetBySystemId(RecSystemId) then
                        Error(RecordNotFoundErr);
                    Clear(IncomingDocumentAttachment.Content);
                    IncomingDocumentAttachment.Modify(true);
                end;
        end;
    end;

    local procedure WriteAttachment(Target: Enum "Storage Attachment Target ori"; RecSystemId: Guid; var TempBlob: Codeunit "Temp Blob"; FileName: Text)
    var
        DocumentAttachment: Record "Document Attachment";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
        ContentInStream: InStream;
    begin
        case Target of
            Target::DocumentAttachment:
                begin
                    if not DocumentAttachment.GetBySystemId(RecSystemId) then
                        Error(RecordNotFoundErr);
                    TempBlob.CreateInStream(ContentInStream);
                    DocumentAttachment.ImportFromStream(ContentInStream, FileName);
                    // ImportFromStream writes the media; the analyzer cannot see the change, so suppress the false AA0214.
#pragma warning disable AA0214
                    DocumentAttachment.Modify(true);
#pragma warning restore AA0214
                end;
            Target::IncomingDocument:
                begin
                    if not IncomingDocumentAttachment.GetBySystemId(RecSystemId) then
                        Error(RecordNotFoundErr);
                    IncomingDocumentAttachment.SetContentFromBlob(TempBlob);
                    // SetContentFromBlob writes the BLOB via a RecordRef; the analyzer cannot see the change, so suppress the false AA0214.
#pragma warning disable AA0214
                    IncomingDocumentAttachment.Modify(true);
#pragma warning restore AA0214
                end;
        end;
    end;

    local procedure GetConnector(StorageCode: Code[20]; var StorageSetup: Record "Storage Setup ori"; var Connector: Interface "Storage Connector ori")
    begin
        if not StorageSetup.Get(StorageCode) then
            Error(UnknownCodeErr, StorageCode);
        if not StorageSetup.Enabled then
            Error(DisabledCodeErr, StorageCode);
        Connector := StorageSetup."Storage Type";
    end;

    local procedure ParseTarget(RequestJson: JsonObject): Enum "Storage Attachment Target ori"
    begin
        exit(ParseTargetProperty(RequestJson, 'target'));
    end;

    local procedure ParseTargetProperty(RequestJson: JsonObject; PropertyName: Text): Enum "Storage Attachment Target ori"
    var
        TargetText: Text;
    begin
        TargetText := RequireText(RequestJson, PropertyName);
        case TargetText of
            'DocumentAttachment':
                exit(Enum::"Storage Attachment Target ori"::DocumentAttachment);
            'IncomingDocument':
                exit(Enum::"Storage Attachment Target ori"::IncomingDocument);
        end;
        Error(UnknownTargetErr, TargetText);
    end;

    local procedure TargetName(Target: Enum "Storage Attachment Target ori"): Text
    begin
        case Target of
            Target::DocumentAttachment:
                exit('DocumentAttachment');
            Target::IncomingDocument:
                exit('IncomingDocument');
        end;
    end;

    local procedure ParseSystemId(RequestJson: JsonObject) RecSystemId: Guid
    var
        IdText: Text;
    begin
        IdText := RequireText(RequestJson, 'systemId');
        if not Evaluate(RecSystemId, IdText) then
            Error(InvalidSystemIdErr, IdText);
    end;

    local procedure RequireText(RequestJson: JsonObject; PropertyName: Text): Text
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Value: Text;
    begin
        Value := RequestMgt.GetText(RequestJson, PropertyName);
        if Value = '' then
            Error(MissingParamErr, PropertyName);
        exit(Value);
    end;

    local procedure ComposeFileName(Name: Text; Extension: Text): Text
    begin
        if Extension = '' then
            exit(Name);
        exit(StrSubstNo('%1.%2', Name, Extension));
    end;

    local procedure FileExtensionOf(FileName: Text): Text
    var
        Index: Integer;
        DotPos: Integer;
    begin
        for Index := 1 to StrLen(FileName) do
            if FileName[Index] = '.' then
                DotPos := Index;
        if DotPos = 0 then
            exit('');
        exit(CopyStr(FileName, DotPos + 1));
    end;

    local procedure GetOptionalInteger(RequestJson: JsonObject; PropertyName: Text) Result: Integer
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ValueText: Text;
    begin
        ValueText := RequestMgt.GetText(RequestJson, PropertyName);
        if ValueText = '' then
            exit(0);
        if not Evaluate(Result, ValueText, 9) then
            exit(0);
    end;

    local procedure BuildPath(Target: Enum "Storage Attachment Target ori"; TableId: Integer; RecSystemId: Guid; FileName: Text; EntryNo: Integer; FolderPath: Text): Text
    var
        Folder: Text;
        IdPart: Text;
        YearPart: Text;
    begin
        Folder := NormalizeFolder(FolderPath);
        if Folder <> '' then
            exit(StrSubstNo('%1/%2', Folder, FileName));

        // Navigable default for incoming documents: group by year (from the posting/document date)
        // then by the entry number, so the blob can be traced back to its incoming document.
        if (Target = Target::IncomingDocument) and (EntryNo <> 0) then begin
            YearPart := IncomingDocumentYear(EntryNo);
            if YearPart <> '' then
                exit(StrSubstNo(IncDocPathWithYearTok, BasePathTok, YearPart, EntryNo, FileName));
            exit(StrSubstNo(IncDocPathTok, BasePathTok, EntryNo, FileName));
        end;

        IdPart := DelChr(Format(RecSystemId, 0, 4), '=', '{}');
        exit(StrSubstNo('%1/%2/%3/%4', BasePathTok, TableId, IdPart, FileName));
    end;

    local procedure IncomingDocumentYear(EntryNo: Integer): Text
    var
        IncomingDocument: Record "Incoming Document";
    begin
        IncomingDocument.SetLoadFields("Posting Date", "Document Date");
        if not IncomingDocument.Get(EntryNo) then
            exit('');
        if IncomingDocument."Posting Date" <> 0D then
            exit(Format(Date2DMY(IncomingDocument."Posting Date", 3)));
        if IncomingDocument."Document Date" <> 0D then
            exit(Format(Date2DMY(IncomingDocument."Document Date", 3)));
        exit('');
    end;

    local procedure NormalizeFolder(FolderPath: Text): Text
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
    begin
        FolderPath := ConvertStr(FolderPath, '\', '/');
        FolderPath := DelChr(FolderPath, '<>', ' /');
        if not RequestMgt.PathIsSafe(FolderPath) then
            RequestMgt.ThrowUnsafePath(FolderPath);
        exit(FolderPath);
    end;
}
