namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.Utilities;

/// <summary>
/// Drives chunked uploads to a storage connection. A caller begins a session, appends the file
/// as a sequence of chunks, then commits — at which point the chunks are assembled in order and
/// written to storage through the configured <c>Bifrost Storage Connector</c>. This lets a file
/// larger than one request can carry be delivered across several Bifrost requests. A chunk may
/// be as large as one request allows (<see cref="Codeunit.StorageRequestReader"/>, 240 MiB), so
/// a file needs as few calls as possible.
/// </summary>
/// <remarks>
/// Every session lookup applies a permanent <c>FilterGroup(2)</c> filter on <c>SystemCreatedBy</c>,
/// so a caller can only ever see and act on the sessions it created — even with a leaked
/// <c>uploadId</c>. Every request value and every session state is checked before the first
/// database write, and all problems are answered together with a stable code. The upload to
/// storage is the last step of a commit, mirroring the offload transaction discipline: a failure
/// before it rolls back the database work, and a failed upload rolls back the status change with it.
/// </remarks>
codeunit 10035665 "Storage Upload Mgt ori"
{
    Access = Internal;

    var
        UploadBasePathTok: Label 'bifrost-uploads', Locked = true;
        DocumentAttachmentTok: Label 'DocumentAttachment', Locked = true;
        IncomingDocumentTok: Label 'IncomingDocument', Locked = true;
        UploadNotFoundErr: Label 'No upload session was found for uploadId "%1".', Comment = '%1 = upload id, is-IS=Engin upphleðslulota fannst fyrir uploadId "%1".';
        UploadNotFoundNextStepLbl: Label 'Start a new upload with Storage.Upload.Begin. A session can only be used by the user who began it.', Comment = 'is-IS=Byrjaðu nýja upphleðslu með Storage.Upload.Begin. Aðeins notandinn sem byrjaði lotuna getur notað hana.';
        NotOpenErr: Label 'The upload session is %1, not open; it has already been committed or aborted.', Comment = '%1 = session status, is-IS=Upphleðslulotan er %1, ekki opin; henni hefur þegar verið lokið eða hún verið hætt.';
        NotOpenNextStepLbl: Label 'Begin a new session with Storage.Upload.Begin to upload the file again.', Comment = 'is-IS=Byrjaðu nýja lotu með Storage.Upload.Begin til að hlaða skránni upp aftur.';
        OpenExpectedLbl: Label 'an open session', Comment = 'is-IS=opin lota';
        NoChunksErr: Label 'The upload session has no chunks to commit.', Comment = 'is-IS=Upphleðslulotan hefur enga hluta til að ljúka.';
        NoChunksNextStepLbl: Label 'Send the file with Storage.Upload.Append first.', Comment = 'is-IS=Sendu skrána fyrst með Storage.Upload.Append.';
        ChunkGapErr: Label 'The upload session is missing one or more chunks: it holds %1 chunks, numbered %2 to %3.', Comment = '%1 = chunk count, %2 = first sequence, %3 = last sequence, is-IS=Það vantar einn eða fleiri hluta í upphleðslulotuna: hún hefur %1 hluta, númeraða %2 til %3.';
        ChunkGapNextStepLbl: Label 'Call Storage.Upload.Status, append the missing sequence numbers, then commit again.', Comment = 'is-IS=Kallaðu á Storage.Upload.Status, bættu við þeim raðnúmerum sem vantar og ljúktu svo aftur.';
        ContiguousExpectedLbl: Label 'contiguous sequence numbers', Comment = 'is-IS=samfelld raðnúmer';
        SizeMismatchErr: Label 'The received size (%1 bytes) does not match the declared size (%2 bytes).', Comment = '%1 = received bytes, %2 = declared bytes, is-IS=Móttekin stærð (%1 bæti) passar ekki við uppgefna stærð (%2 bæti).';
        SizeMismatchNextStepLbl: Label 'Append the missing chunks, or re-send a chunk whose content was wrong, then commit again.', Comment = 'is-IS=Bættu við hlutunum sem vantar eða sendu aftur hluta með röngu innihaldi og ljúktu svo aftur.';
        NoStorageCodeErr: Label 'This upload session has no storage connection, so it cannot be written to storage.', Comment = 'is-IS=Þessi upphleðslulota hefur enga geymslutengingu og því er ekki hægt að skrifa hana í geymslu.';
        NoStorageCodeNextStepLbl: Label 'Use Storage.Upload.CommitToRecord to attach the file to a record, or begin a new session with a storageCode.', Comment = 'is-IS=Notaðu Storage.Upload.CommitToRecord til að hengja skrána við færslu eða byrjaðu nýja lotu með storageCode.';
        UnknownTargetErr: Label 'Parameter "target" has value "%1", which is not an attachment target.', Comment = '%1 = received value, is-IS=Færibreytan "target" hefur gildið "%1", sem er ekki viðhengjamarkmið.';
        TargetExpectedLbl: Label 'DocumentAttachment or IncomingDocument', Locked = true;

    /// <summary>Opens a chunked upload session and returns its <c>uploadId</c>.</summary>
    /// <param name="Argument">The message argument carrying <c>fileName</c> and optional <c>storageCode</c>/<c>path</c>/<c>folderPath</c>/<c>declaredSize</c>; receives the error response.</param>
    /// <param name="ResultData">Out: the success payload describing the new session.</param>
    /// <returns>True when the session was opened; false when an error response was written.</returns>
    procedure BeginUpload(var Argument: Record "Message Argument ori"; var ResultData: JsonObject): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
        Session: Record "Storage Upload Session ori";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        RequestJson: JsonObject;
        StorageCode: Text;
        FileName: Text;
        Path: Text;
        FolderPath: Text;
        DeclaredSize: Integer;
        UploadId: Guid;
    begin
        RequestJson := Argument.GetRequestJson();
        Reader.ReadText(Argument, RequestJson, 'storageCode', false, StorageCode);
        if StorageCode <> '' then
            RequestMgt.ResolveSetup(Argument, StorageCode, 'storageCode', StorageSetup, Connector);
        Reader.ReadText(Argument, RequestJson, 'fileName', true, FileName);
        Reader.ReadPath(Argument, RequestJson, 'path', false, Path);
        Reader.ReadPath(Argument, RequestJson, 'folderPath', false, FolderPath);
        Reader.ReadNonNegativeInteger(Argument, RequestJson, 'declaredSize', false, DeclaredSize);
        if Reader.RespondIfErrors(Argument) then
            exit(false);

        UploadId := CreateGuid();
        Session.Init();
        Session."Upload Id" := UploadId;
        Session."Storage Code" := StorageSetup."Code";
        Session."File Name" := CopyStr(FileName, 1, MaxStrLen(Session."File Name"));
        if StorageCode <> '' then
            Session."Target Path" := CopyStr(ResolveTargetPath(Path, FolderPath, FileName), 1, MaxStrLen(Session."Target Path"));
        Session."Declared Size" := DeclaredSize;
        Session.Status := Session.Status::Open;
        Session.Insert(true);

        ResultData.Add('uploadId', Format(UploadId, 0, 4));
        ResultData.Add('storageCode', Session."Storage Code");
        ResultData.Add('path', Session."Target Path");
        ResultData.Add('chunkSizeHint', RecommendedChunkBytes());
        ResultData.Add('maxChunkBytes', Reader.MaxContentBytes());
        exit(true);
    end;

    /// <summary>Appends one chunk to an open session. Re-appending the same sequence replaces it.</summary>
    /// <param name="Argument">The message argument carrying <c>uploadId</c>, <c>sequence</c> and <c>contentBase64</c>; receives the error response.</param>
    /// <param name="ResultData">Out: the success payload describing progress so far.</param>
    /// <returns>True when the chunk was stored; false when an error response was written.</returns>
    procedure AppendChunk(var Argument: Record "Message Argument ori"; var ResultData: JsonObject): Boolean
    var
        Session: Record "Storage Upload Session ori";
        Chunk: Record "Storage Upload Chunk ori";
        TempBlob: Codeunit "Temp Blob";
        Reader: Codeunit "Storage Request Reader ori";
        RequestJson: JsonObject;
        UploadId: Guid;
        SequenceNo: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        Reader.ReadGuid(Argument, RequestJson, 'uploadId', true, UploadId);
        Reader.ReadInteger(Argument, RequestJson, 'sequence', true, SequenceNo);
        Reader.ReadBase64Content(Argument, RequestJson, 'contentBase64', true, TempBlob);
        if Reader.RespondIfErrors(Argument) then
            exit(false);
        if not FindOpenSession(Argument, UploadId, Session) then
            exit(false);

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
        exit(true);
    end;

    /// <summary>Assembles an open session's chunks and writes the file to storage.</summary>
    /// <param name="Argument">The message argument carrying <c>uploadId</c>; receives the error response.</param>
    /// <param name="ResultData">Out: the success payload describing the stored file.</param>
    /// <returns>True when the file was written; false when an error response was written.</returns>
    procedure CommitUpload(var Argument: Record "Message Argument ori"; var ResultData: JsonObject): Boolean
    var
        Session: Record "Storage Upload Session ori";
        StorageSetup: Record "Storage Setup ori";
        TempBlob: Codeunit "Temp Blob";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        UploadId: Guid;
    begin
        Reader.ReadGuid(Argument, Argument.GetRequestJson(), 'uploadId', true, UploadId);
        if Reader.RespondIfErrors(Argument) then
            exit(false);
        if not FindOpenSession(Argument, UploadId, Session) then
            exit(false);
        if not CheckReadyToCommit(Argument, Session) then
            exit(false);
        if Session."Storage Code" = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NoStorageCodeErr, 'uploadId', Format(UploadId, 0, 4), '', NoStorageCodeNextStepLbl);
            exit(false);
        end;
        // The connection is the one named when the session began, not a request value.
        if not RequestMgt.ResolveSetup(Argument, Session."Storage Code", '', StorageSetup, Connector) then begin
            Reader.RespondIfErrors(Argument);
            exit(false);
        end;
        AssembleChunks(UploadId, TempBlob);

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
        exit(true);
    end;

    /// <summary>Assembles chunks and attaches the file to a BC record or incoming document without external storage.</summary>
    /// <param name="Argument">The message argument carrying <c>uploadId</c>, optional <c>target</c> and the target's address; receives the error response.</param>
    /// <param name="ResultData">Out: the success payload describing the new attachment.</param>
    /// <returns>True when the attachment was created; false when an error response was written.</returns>
    procedure CommitToRecord(var Argument: Record "Message Argument ori"; var ResultData: JsonObject): Boolean
    var
        Session: Record "Storage Upload Session ori";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        TempBlob: Codeunit "Temp Blob";
        Reader: Codeunit "Storage Request Reader ori";
        RequestJson: JsonObject;
        UploadId: Guid;
        Target: Text;
        Created: Boolean;
    begin
        RequestJson := Argument.GetRequestJson();
        Reader.ReadGuid(Argument, RequestJson, 'uploadId', true, UploadId);
        Reader.ReadText(Argument, RequestJson, 'target', false, Target);
        if (Target <> '') and (Target <> DocumentAttachmentTok) and (Target <> IncomingDocumentTok) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(UnknownTargetErr, Target), 'target', Target, TargetExpectedLbl, '');
        if Reader.RespondIfErrors(Argument) then
            exit(false);
        if not FindOpenSession(Argument, UploadId, Session) then
            exit(false);
        if not CheckReadyToCommit(Argument, Session) then
            exit(false);

        AssembleChunks(UploadId, TempBlob);
        if Target = IncomingDocumentTok then
            Created := AttachmentMgt.CreateIncomingFromBlob(Argument, TempBlob, Session."File Name", ResultData)
        else
            Created := AttachmentMgt.CreateForRecordFromBlob(Argument, TempBlob, Session."File Name", ResultData);
        if not Created then
            exit(false);

        Session.Status := Session.Status::Committed;
        Session."Received Size" := TempBlob.Length();
        Session.Modify(true);
        DeleteChunks(UploadId);
        exit(true);
    end;

    /// <summary>Discards an open session and all its chunks without writing anything to storage.</summary>
    /// <param name="Argument">The message argument carrying <c>uploadId</c>; receives the error response.</param>
    /// <param name="ResultData">Out: the success payload confirming the session was aborted.</param>
    /// <returns>True when the session was discarded; false when an error response was written.</returns>
    procedure AbortUpload(var Argument: Record "Message Argument ori"; var ResultData: JsonObject): Boolean
    var
        Session: Record "Storage Upload Session ori";
        Reader: Codeunit "Storage Request Reader ori";
        UploadId: Guid;
    begin
        Reader.ReadGuid(Argument, Argument.GetRequestJson(), 'uploadId', true, UploadId);
        if Reader.RespondIfErrors(Argument) then
            exit(false);
        if not FindOpenSession(Argument, UploadId, Session) then
            exit(false);
        Session.Delete(true);

        ResultData.Add('uploadId', Format(UploadId, 0, 4));
        ResultData.Add('status', StatusName(Session.Status::Aborted));
        exit(true);
    end;

    /// <summary>Reports the progress and state of a session.</summary>
    /// <param name="Argument">The message argument carrying <c>uploadId</c>; receives the error response.</param>
    /// <param name="ResultData">Out: the success payload describing the session.</param>
    /// <returns>True when the session was found; false when an error response was written.</returns>
    procedure GetStatus(var Argument: Record "Message Argument ori"; var ResultData: JsonObject): Boolean
    var
        Session: Record "Storage Upload Session ori";
        Reader: Codeunit "Storage Request Reader ori";
        UploadId: Guid;
    begin
        Reader.ReadGuid(Argument, Argument.GetRequestJson(), 'uploadId', true, UploadId);
        if Reader.RespondIfErrors(Argument) then
            exit(false);
        if not FindOwnSession(UploadId, Session) then begin
            RespondUploadNotFound(Argument, UploadId);
            exit(false);
        end;

        ResultData.Add('uploadId', Format(UploadId, 0, 4));
        ResultData.Add('storageCode', Session."Storage Code");
        ResultData.Add('fileName', Session."File Name");
        ResultData.Add('path', Session."Target Path");
        ResultData.Add('status', StatusName(Session.Status));
        ResultData.Add('declaredSize', Session."Declared Size");
        ResultData.Add('received', Session."Received Size");
        ResultData.Add('chunkCount', Session."Chunk Count");
        exit(true);
    end;

    /// <summary>
    /// Returns the chunk size in bytes callers should target: the largest a single request can
    /// carry, because every chunk is one billable message.
    /// </summary>
    /// <returns>The suggested chunk size in bytes.</returns>
    procedure RecommendedChunkBytes(): Integer
    var
        Reader: Codeunit "Storage Request Reader ori";
    begin
        exit(Reader.MaxContentBytes());
    end;

    local procedure CheckReadyToCommit(var Argument: Record "Message Argument ori"; Session: Record "Storage Upload Session ori"): Boolean
    var
        FirstSequence: Integer;
        LastSequence: Integer;
        UploadIdText: Text;
    begin
        UploadIdText := Format(Session."Upload Id", 0, 4);
        if Session."Chunk Count" = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NoChunksErr, 'uploadId', UploadIdText, '', NoChunksNextStepLbl);
            exit(false);
        end;
        GetSequenceRange(Session."Upload Id", FirstSequence, LastSequence);
        if (LastSequence - FirstSequence + 1) <> Session."Chunk Count" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed,
                StrSubstNo(ChunkGapErr, Session."Chunk Count", FirstSequence, LastSequence), 'uploadId', UploadIdText, ContiguousExpectedLbl, ChunkGapNextStepLbl);
            exit(false);
        end;
        if (Session."Declared Size" > 0) and (Session."Declared Size" <> Session."Received Size") then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed,
                StrSubstNo(SizeMismatchErr, Session."Received Size", Session."Declared Size"), 'declaredSize',
                Format(Session."Received Size", 0, 9), Format(Session."Declared Size", 0, 9), SizeMismatchNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure GetSequenceRange(UploadId: Guid; var FirstSequence: Integer; var LastSequence: Integer)
    var
        Chunk: Record "Storage Upload Chunk ori";
    begin
        Chunk.SetLoadFields("Upload Id", "Sequence No.");
        Chunk.SetRange("Upload Id", UploadId);
        Chunk.FindFirst();
        FirstSequence := Chunk."Sequence No.";
        Chunk.FindLast();
        LastSequence := Chunk."Sequence No.";
    end;

    local procedure AssembleChunks(UploadId: Guid; var TempBlob: Codeunit "Temp Blob")
    var
        Chunk: Record "Storage Upload Chunk ori";
        ContentOutStream: OutStream;
    begin
        Chunk.SetCurrentKey("Upload Id", "Sequence No.");
        Chunk.Ascending(true);
        Chunk.SetRange("Upload Id", UploadId);
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

    local procedure FindOpenSession(var Argument: Record "Message Argument ori"; UploadId: Guid; var Session: Record "Storage Upload Session ori"): Boolean
    begin
        if not FindOwnSession(UploadId, Session) then begin
            RespondUploadNotFound(Argument, UploadId);
            exit(false);
        end;
        if Session.Status = Session.Status::Open then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotOpenErr, StatusName(Session.Status)), 'uploadId',
            Format(UploadId, 0, 4), OpenExpectedLbl, NotOpenNextStepLbl);
        exit(false);
    end;

    local procedure RespondUploadNotFound(var Argument: Record "Message Argument ori"; UploadId: Guid)
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UploadNotFoundErr, Format(UploadId, 0, 4)), 'uploadId', Format(UploadId, 0, 4), '', UploadNotFoundNextStepLbl);
    end;

    local procedure ResolveTargetPath(Path: Text; FolderPath: Text; FileName: Text): Text
    var
        Folder: Text;
    begin
        Path := NormalizeFolder(Path);
        if Path <> '' then
            exit(Path);
        Folder := NormalizeFolder(FolderPath);
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
}
