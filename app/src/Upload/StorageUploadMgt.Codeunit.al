namespace Origo.Bifrost.Attachments;

using System.Text;
using System.Utilities;

/// <summary>
/// Drives chunked uploads to a storage connection. A caller begins a session, appends the file
/// as a sequence of small base64 chunks, then commits — at which point the chunks are assembled
/// in order and written to storage through the configured <c>Bifrost Storage Connector</c>. This
/// lets large files be delivered across many small Bifrost requests instead of one
/// oversized call.
/// </summary>
/// <remarks>
/// Every session lookup applies a permanent <c>FilterGroup(2)</c> filter on <c>SystemCreatedBy</c>,
/// so a caller can only ever see and act on the sessions it created — even with a leaked
/// <c>uploadId</c>. The upload to storage is the last step of a commit, mirroring the offload
/// transaction discipline: a failure before it rolls back the database work, and a failed upload
/// rolls back the status change with it.
/// </remarks>
codeunit 10035665 "Storage Upload Mgt ori"
{
    Access = Internal;

    var
        UploadBasePathTok: Label 'bifrost-uploads', Locked = true;
        MissingParamErr: Label 'Missing required ''%1'' in the request.', Comment = '%1 = parameter name', Locked = true;
        InvalidIntegerErr: Label '''%1'' must be a whole number; got ''%2''.', Comment = '%1 = parameter name, %2 = value', Locked = true;
        InvalidUploadIdErr: Label '''%1'' is not a valid uploadId.', Comment = '%1 = upload id text', Locked = true;
        UnknownCodeErr: Label 'No storage connection is configured for storageCode ''%1''.', Comment = '%1 = storage code', Locked = true;
        DisabledCodeErr: Label 'The storage connection ''%1'' is disabled.', Comment = '%1 = storage code', Locked = true;
        UploadNotFoundErr: Label 'No upload session was found for the supplied uploadId.', Locked = true;
        NotOpenErr: Label 'The upload session is not open; it has already been committed or aborted.', Locked = true;
        NoChunksErr: Label 'The upload session has no chunks to commit.', Locked = true;
        ChunkGapErr: Label 'The upload session is missing one or more chunks; the sequence numbers are not contiguous.', Locked = true;
        SizeMismatchErr: Label 'The received size (%1 bytes) does not match the declared size (%2 bytes).', Comment = '%1 = received bytes, %2 = declared bytes', Locked = true;
        NoStorageCodeErr: Label 'This upload session has no storage connection. Use Storage.Upload.CommitToRecord to attach it to a record, or begin a new session with a storageCode.', Locked = true;
        UnknownTargetErr: Label 'Unknown target ''%1''. Use ''DocumentAttachment'' or ''IncomingDocument''.', Comment = '%1 = target', Locked = true;

    /// <summary>Opens a chunked upload session and returns its <c>uploadId</c>.</summary>
    /// <param name="RequestJson">Request carrying <c>storageCode</c>, <c>fileName</c> and optional <c>path</c>/<c>folderPath</c>/<c>declaredSize</c>.</param>
    /// <param name="ResultData">Out: the success payload describing the new session.</param>
    procedure BeginUpload(RequestJson: JsonObject; var ResultData: JsonObject)
    var
        StorageSetup: Record "Storage Setup ori";
        Session: Record "Storage Upload Session ori";
        Connector: Interface "Storage Connector ori";
        StorageCode: Code[20];
        FileName: Text;
        UploadId: Guid;
    begin
        StorageCode := CopyStr(GetText(RequestJson, 'storageCode'), 1, MaxStrLen(StorageCode));
        if StorageCode <> '' then
            GetConnector(StorageCode, StorageSetup, Connector);
        FileName := RequireText(RequestJson, 'fileName');

        UploadId := CreateGuid();
        Session.Init();
        Session."Upload Id" := UploadId;
        Session."Storage Code" := StorageCode;
        Session."File Name" := CopyStr(FileName, 1, MaxStrLen(Session."File Name"));
        if StorageCode <> '' then
            Session."Target Path" := CopyStr(ResolveTargetPath(RequestJson, FileName), 1, MaxStrLen(Session."Target Path"));
        Session."Declared Size" := GetInteger(RequestJson, 'declaredSize');
        Session.Status := Session.Status::Open;
        Session.Insert(true);

        ResultData.Add('uploadId', Format(UploadId, 0, 4));
        ResultData.Add('storageCode', StorageCode);
        ResultData.Add('path', Session."Target Path");
        ResultData.Add('chunkSizeHint', RecommendedChunkBytes());
    end;

    /// <summary>Appends one chunk to an open session. Re-appending the same sequence replaces it.</summary>
    /// <param name="RequestJson">Request carrying <c>uploadId</c>, <c>sequence</c> and <c>contentBase64</c>.</param>
    /// <param name="ResultData">Out: the success payload describing progress so far.</param>
    procedure AppendChunk(RequestJson: JsonObject; var ResultData: JsonObject)
    var
        Session: Record "Storage Upload Session ori";
        Chunk: Record "Storage Upload Chunk ori";
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        UploadId: Guid;
        SequenceNo: Integer;
        ContentBase64: Text;
        ContentOutStream: OutStream;
    begin
        UploadId := ParseUploadId(RequestJson);
        SequenceNo := RequireInteger(RequestJson, 'sequence');
        ContentBase64 := RequireText(RequestJson, 'contentBase64');
        GetOpenSession(UploadId, Session);

        TempBlob.CreateOutStream(ContentOutStream);
        Base64Convert.FromBase64(ContentBase64, ContentOutStream);

        if Chunk.Get(UploadId, SequenceNo) then begin
            Session."Received Size" -= Chunk.Size;
            Session."Chunk Count" -= 1;
            Chunk.Delete(true);
        end;
        Chunk.Init();
        Chunk."Upload Id" := UploadId;
        Chunk."Sequence No." := SequenceNo;
        Chunk.SetContentFromBlob(TempBlob);
        Chunk.Size := TempBlob.Length();
        Chunk.Insert(true);

        Session."Received Size" += Chunk.Size;
        Session."Chunk Count" += 1;
        Session.Modify(true);

        ResultData.Add('uploadId', Format(UploadId, 0, 4));
        ResultData.Add('sequence', SequenceNo);
        ResultData.Add('received', Session."Received Size");
        ResultData.Add('chunkCount', Session."Chunk Count");
    end;

    /// <summary>Assembles an open session's chunks and writes the file to storage.</summary>
    /// <param name="RequestJson">Request carrying <c>uploadId</c>.</param>
    /// <param name="ResultData">Out: the success payload describing the stored file.</param>
    procedure CommitUpload(RequestJson: JsonObject; var ResultData: JsonObject)
    var
        Session: Record "Storage Upload Session ori";
        StorageSetup: Record "Storage Setup ori";
        TempBlob: Codeunit "Temp Blob";
        Connector: Interface "Storage Connector ori";
        UploadId: Guid;
    begin
        UploadId := ParseUploadId(RequestJson);
        GetOpenSession(UploadId, Session);

        if Session."Chunk Count" = 0 then
            Error(NoChunksErr);
        if (Session."Declared Size" > 0) and (Session."Declared Size" <> Session."Received Size") then
            Error(SizeMismatchErr, Session."Received Size", Session."Declared Size");

        if Session."Storage Code" = '' then
            Error(NoStorageCodeErr);
        GetConnector(Session."Storage Code", StorageSetup, Connector);
        AssembleChunks(UploadId, Session."Chunk Count", TempBlob);

        // Database work first, then the upload last: a failure before the upload rolls back the
        // status change, and a failed upload rolls it back too — leaving the session reusable.
        Session.Status := Session.Status::Committed;
        Session."Received Size" := TempBlob.Length();
        Session.Modify(true);
        DeleteChunks(UploadId);

        Connector.CreateFile(StorageSetup, Session."Target Path", TempBlob);

        ResultData.Add('uploadId', Format(UploadId, 0, 4));
        ResultData.Add('storageCode', Session."Storage Code");
        ResultData.Add('path', Session."Target Path");
        ResultData.Add('contentLength', TempBlob.Length());
    end;

    /// <summary>Assembles chunks and attaches the file to a BC record or incoming document without external storage.</summary>
    procedure CommitToRecord(RequestJson: JsonObject; var ResultData: JsonObject)
    var
        Session: Record "Storage Upload Session ori";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        TempBlob: Codeunit "Temp Blob";
        UploadId: Guid;
        Target: Text;
    begin
        UploadId := ParseUploadId(RequestJson);
        GetOpenSession(UploadId, Session);

        if Session."Chunk Count" = 0 then
            Error(NoChunksErr);
        if (Session."Declared Size" > 0) and (Session."Declared Size" <> Session."Received Size") then
            Error(SizeMismatchErr, Session."Received Size", Session."Declared Size");

        AssembleChunks(UploadId, Session."Chunk Count", TempBlob);

        Target := GetText(RequestJson, 'target');
        if (Target = '') or (Target = 'DocumentAttachment') then
            AttachmentMgt.CreateForRecordFromBlob(RequestJson, TempBlob, Session."File Name", ResultData)
        else
            if Target = 'IncomingDocument' then
                AttachmentMgt.CreateIncomingFromBlob(RequestJson, TempBlob, Session."File Name", ResultData)
            else
                Error(UnknownTargetErr, Target);

        Session.Status := Session.Status::Committed;
        Session."Received Size" := TempBlob.Length();
        Session.Modify(true);
        DeleteChunks(UploadId);
    end;

    /// <summary>Discards an open session and all its chunks without writing anything to storage.</summary>
    /// <param name="RequestJson">Request carrying <c>uploadId</c>.</param>
    /// <param name="ResultData">Out: the success payload confirming the session was aborted.</param>
    procedure AbortUpload(RequestJson: JsonObject; var ResultData: JsonObject)
    var
        Session: Record "Storage Upload Session ori";
        UploadId: Guid;
    begin
        UploadId := ParseUploadId(RequestJson);
        GetOpenSession(UploadId, Session);
        Session.Delete(true);

        ResultData.Add('uploadId', Format(UploadId, 0, 4));
        ResultData.Add('status', 'Aborted');
    end;

    /// <summary>Reports the progress and state of a session.</summary>
    /// <param name="RequestJson">Request carrying <c>uploadId</c>.</param>
    /// <param name="ResultData">Out: the success payload describing the session.</param>
    procedure GetStatus(RequestJson: JsonObject; var ResultData: JsonObject)
    var
        Session: Record "Storage Upload Session ori";
        UploadId: Guid;
    begin
        UploadId := ParseUploadId(RequestJson);
        if not FindOwnSession(UploadId, Session) then
            Error(UploadNotFoundErr);

        ResultData.Add('uploadId', Format(UploadId, 0, 4));
        ResultData.Add('storageCode', Session."Storage Code");
        ResultData.Add('fileName', Session."File Name");
        ResultData.Add('path', Session."Target Path");
        ResultData.Add('status', StatusName(Session.Status));
        ResultData.Add('declaredSize', Session."Declared Size");
        ResultData.Add('received', Session."Received Size");
        ResultData.Add('chunkCount', Session."Chunk Count");
    end;

    /// <summary>Returns the recommended raw chunk size in bytes for callers to target.</summary>
    /// <returns>The suggested chunk size in bytes.</returns>
    procedure RecommendedChunkBytes(): Integer
    begin
        exit(49152); // 48 KB raw (~64 KB as base64), well within a single request.
    end;

    local procedure AssembleChunks(UploadId: Guid; ExpectedCount: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        Chunk: Record "Storage Upload Chunk ori";
        ContentOutStream: OutStream;
        FirstSequence: Integer;
        LastSequence: Integer;
    begin
        Chunk.SetCurrentKey("Upload Id", "Sequence No.");
        Chunk.Ascending(true);
        Chunk.SetRange("Upload Id", UploadId);
        Chunk.FindFirst();
        FirstSequence := Chunk."Sequence No.";
        Chunk.FindLast();
        LastSequence := Chunk."Sequence No.";
        if (LastSequence - FirstSequence + 1) <> ExpectedCount then
            Error(ChunkGapErr);

        TempBlob.CreateOutStream(ContentOutStream);
        Chunk.FindSet();
        repeat
            Chunk.AppendContentTo(ContentOutStream);
        until Chunk.Next() = 0;
    end;

    local procedure DeleteChunks(UploadId: Guid)
    var
        Chunk: Record "Storage Upload Chunk ori";
    begin
        Chunk.SetRange("Upload Id", UploadId);
        Chunk.DeleteAll(true);
    end;

    local procedure FindOwnSession(UploadId: Guid; var Session: Record "Storage Upload Session ori"): Boolean
    begin
        Session.Reset();
        Session.FilterGroup(2);
        Session.SetRange(SystemCreatedBy, UserSecurityId());
        Session.FilterGroup(0);
        Session.SetRange("Upload Id", UploadId);
        exit(Session.FindFirst());
    end;

    local procedure GetOpenSession(UploadId: Guid; var Session: Record "Storage Upload Session ori")
    begin
        if not FindOwnSession(UploadId, Session) then
            Error(UploadNotFoundErr);
        if Session.Status <> Session.Status::Open then
            Error(NotOpenErr);
    end;

    local procedure GetConnector(StorageCode: Code[20]; var StorageSetup: Record "Storage Setup ori"; var Connector: Interface "Storage Connector ori")
    begin
        if not StorageSetup.Get(StorageCode) then
            Error(UnknownCodeErr, StorageCode);
        if not StorageSetup.Enabled then
            Error(DisabledCodeErr, StorageCode);
        Connector := StorageSetup."Storage Type";
    end;

    local procedure ResolveTargetPath(RequestJson: JsonObject; FileName: Text) Path: Text
    var
        Folder: Text;
    begin
        Path := NormalizeFolder(GetText(RequestJson, 'path'));
        if Path <> '' then
            exit(Path);
        Folder := NormalizeFolder(GetText(RequestJson, 'folderPath'));
        if Folder <> '' then
            exit(StrSubstNo('%1/%2', Folder, FileName));
        exit(StrSubstNo('%1/%2', UploadBasePathTok, FileName));
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

    local procedure StatusName(Status: Enum "Storage Upload Status ori"): Text
    begin
        case Status of
            Status::Open:
                exit('Open');
            Status::Committed:
                exit('Committed');
            Status::Aborted:
                exit('Aborted');
        end;
    end;

    local procedure ParseUploadId(RequestJson: JsonObject) UploadId: Guid
    var
        IdText: Text;
    begin
        IdText := RequireText(RequestJson, 'uploadId');
        if not Evaluate(UploadId, IdText) then
            Error(InvalidUploadIdErr, IdText);
    end;

    local procedure RequireText(RequestJson: JsonObject; PropertyName: Text): Text
    var
        Value: Text;
    begin
        Value := GetText(RequestJson, PropertyName);
        if Value = '' then
            Error(MissingParamErr, PropertyName);
        exit(Value);
    end;

    local procedure GetText(RequestJson: JsonObject; PropertyName: Text): Text
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
    begin
        exit(RequestMgt.GetText(RequestJson, PropertyName));
    end;

    local procedure GetInteger(RequestJson: JsonObject; PropertyName: Text) Result: Integer
    var
        ValueText: Text;
    begin
        ValueText := GetText(RequestJson, PropertyName);
        if ValueText = '' then
            exit(0);
        if not Evaluate(Result, ValueText, 9) then
            Error(InvalidIntegerErr, PropertyName, ValueText);
    end;

    local procedure RequireInteger(RequestJson: JsonObject; PropertyName: Text) Result: Integer
    var
        ValueText: Text;
    begin
        ValueText := GetText(RequestJson, PropertyName);
        if ValueText = '' then
            Error(MissingParamErr, PropertyName);
        if not Evaluate(Result, ValueText, 9) then
            Error(InvalidIntegerErr, PropertyName, ValueText);
    end;
}
