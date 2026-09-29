namespace Origo.Bifrost.Attachments;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using Origo.Bifrost;
using System.DataAdministration;
using System.Reflection;
using System.Utilities;

/// <summary>
/// Moves attachment file content between the Business Central database and external storage.
/// Offload reads the current content, uploads it through the configured <c>Bifrost Storage
/// Connector</c>, records a <c>Bifrost Storage Attachment Link</c> row and clears the local
/// content. Restore fetches the content back, writes it into the record, deletes the remote
/// copy and removes the link. The same connector helpers serve content transparently to the
/// table read hooks (see <see cref="Codeunit.StorageAttachmentSubscr"/>).
/// </summary>
/// <remarks>
/// The message-type procedures read every request value first and answer all problems at once
/// with a stable code. Everything they can check is checked before the first database write, so
/// such an answer leaves nothing behind. A problem that only shows after a write is raised with
/// <c>RaiseCollectedErrors</c>, which rolls the write back and still reaches the caller structured.
/// </remarks>
codeunit 10035635 "Storage Attachment Mgt ori"
{
    Access = Internal;

    var
        BasePathTok: Label 'bifrost-attachments', Locked = true;
        IncDocPathWithYearTok: Label '%1/incoming-documents/%2/%3/%4', Comment = '%1 = base path, %2 = year, %3 = entry no., %4 = file name', Locked = true;
        IncDocPathTok: Label '%1/incoming-documents/%2/%3', Comment = '%1 = base path, %2 = entry no., %3 = file name', Locked = true;
        DocumentAttachmentTok: Label 'DocumentAttachment', Locked = true;
        IncomingDocumentTok: Label 'IncomingDocument', Locked = true;
        UnknownTargetErr: Label 'Parameter "%1" has value "%2", which is not an attachment target.', Comment = '%1 = parameter, %2 = received value, is-IS=Færibreyta "%1" hefur gildið "%2", sem er ekki viðhengjamarkmið.';
        TargetExpectedLbl: Label 'DocumentAttachment or IncomingDocument', Locked = true;
        UnknownCodeErr: Label 'No storage connection is configured for storageCode "%1".', Comment = '%1 = storage code, is-IS=Engin geymslutenging er skilgreind fyrir storageCode "%1".';
        DisabledCodeErr: Label 'The storage connection "%1" is disabled.', Comment = '%1 = storage code, is-IS=Geymslutengingin "%1" er óvirk.';
        RecordNotFoundErr: Label '%1 "%2" was not found (from %3).', Comment = '%1 = table caption, %2 = value received, %3 = request parameter, is-IS=%1 "%2" fannst ekki (úr %3).';
        RecordNotFoundNextStepLbl: Label 'Check the record with Data.Records.Get on table %1.', Comment = '%1 = table caption, is-IS=Athugaðu færsluna með Data.Records.Get á töflunni %1.';
        NoContentErr: Label 'The attachment has no content.', Comment = 'is-IS=Viðhengið hefur ekkert innihald.';
        NoContentNextStepLbl: Label 'Add the file to the attachment in Business Central first.', Comment = 'is-IS=Bættu skránni fyrst við viðhengið í Business Central.';
        AlreadyOffloadedErr: Label 'The attachment is already offloaded.', Comment = 'is-IS=Viðhengið hefur þegar verið útvistað.';
        AlreadyOffloadedNextStepLbl: Label 'Restore it with Storage.Attachment.Restore before offloading it again.', Comment = 'is-IS=Endurheimtu það með Storage.Attachment.Restore áður en þú útvistar því aftur.';
        NotOffloadedErr: Label 'The attachment is not offloaded, so there is nothing to restore.', Comment = 'is-IS=Viðhenginu hefur ekki verið útvistað og því er ekkert að endurheimta.';
        NotOffloadedNextStepLbl: Label 'Read the Offloaded ori field of the attachment to find the offloaded ones.', Comment = 'is-IS=Lestu reitinn Offloaded ori á viðhenginu til að finna þau sem hefur verið útvistað.';
        OffloadedExpectedLbl: Label 'an offloaded attachment', Comment = 'is-IS=útvistað viðhengi';
        NotOffloadedExpectedLbl: Label 'an attachment that is not offloaded', Comment = 'is-IS=viðhengi sem hefur ekki verið útvistað';
        NoStorageFileErr: Label 'No file was found in storage at "%1".', Comment = '%1 = storage path, is-IS=Engin skrá fannst í geymslunni á "%1".';
        NoStorageFileNextStepLbl: Label 'Check the path with Storage.File.Exists or Storage.File.List.', Comment = 'is-IS=Athugaðu slóðina með Storage.File.Exists eða Storage.File.List.';
        PathAlreadyLinkedErr: Label 'The storage path "%1" on connection "%2" already backs another attachment. Each storage file can back only one attachment.', Comment = '%1 = storage path, %2 = storage code, is-IS=Geymsluslóðin "%1" á tengingunni "%2" geymir þegar annað viðhengi. Hver skrá í geymslunni getur aðeins geymt eitt viðhengi.';
        PathAlreadyLinkedNextStepLbl: Label 'Copy the file with Storage.File.Copy and link the copy, or attach the file with content instead.', Comment = 'is-IS=Afritaðu skrána með Storage.File.Copy og tengdu afritið eða hengdu skrána við með innihaldi.';
        UnlinkedExpectedLbl: Label 'a file that no attachment is linked to', Comment = 'is-IS=skrá sem ekkert viðhengi er tengt við';
        LinkPermissionErr: Label 'You do not have permission to update Bifröst storage attachment links.', Comment = 'is-IS=Þú hefur ekki heimild til að uppfæra viðhengjatengingar Bifröst geymslu.';
        TargetPermissionErr: Label 'You do not have permission to update the linked Business Central table %1.', Comment = '%1 = table id, is-IS=Þú hefur ekki heimild til að uppfæra tengdu Business Central töfluna %1.';
        ReadPermissionErr: Label 'You do not have permission to read table %1.', Comment = '%1 = table id, is-IS=Þú hefur ekki heimild til að lesa töflu %1.';
        UnknownTableErr: Label 'Table %1 does not exist.', Comment = '%1 = table id, is-IS=Tafla %1 er ekki til.';
        UnknownTableNameErr: Label 'No table named "%1" exists.', Comment = '%1 = table name, is-IS=Engin tafla heitir "%1".';
        UnknownTableNextStepLbl: Label 'Find the table with Help.Tables.Get.', Comment = 'is-IS=Finndu töfluna með Help.Tables.Get.';
        TableRequiredErr: Label 'Send tableId or tableName to say which table the record is in.', Comment = 'is-IS=Sendu tableId eða tableName til að segja í hvaða töflu færslan er.';
        TableExpectedLbl: Label 'tableId or tableName', Locked = true;
        RecordRequiredErr: Label 'Send recordSystemId or no to say which record the attachment belongs to.', Comment = 'is-IS=Sendu recordSystemId eða no til að segja hvaða færslu viðhengið tilheyrir.';
        RecordExpectedLbl: Label 'recordSystemId or no', Locked = true;
        CompositeKeyErr: Label 'Table %1 has a composite primary key, so it cannot be addressed with "no".', Comment = '%1 = table id, is-IS=Tafla %1 hefur samsettan aðallykil og því er ekki hægt að vísa í hana með "no".';
        NonCodeKeyErr: Label 'The primary key of table %1 is not a code or text field, so it cannot be addressed with "no".', Comment = '%1 = table id, is-IS=Aðallykill töflu %1 er hvorki kóða- né textareitur og því er ekki hægt að vísa í hana með "no".';
        UseRecordSystemIdLbl: Label 'Send recordSystemId instead.', Comment = 'is-IS=Sendu recordSystemId í staðinn.';
        RecordNoTooLongErr: Label 'The record identifier "%1" is longer than the 20 characters a document attachment can hold.', Comment = '%1 = record identifier, is-IS=Færsluauðkennið "%1" er lengra en þeir 20 stafir sem viðhengi skjals getur geymt.';
        RecordNoExpectedLbl: Label 'at most 20 characters', Comment = 'is-IS=í mesta lagi 20 stafir';
        ContentSourceErr: Label 'Send exactly one content source: contentBase64 (or the alias content), storageCode with path, or sourceTarget with sourceSystemId.', Comment = 'is-IS=Sendu nákvæmlega eina uppsprettu innihalds: contentBase64 (eða samheitið content), storageCode með path eða sourceTarget með sourceSystemId.';
        ContentSourceParameterTok: Label 'contentBase64, storageCode, sourceSystemId', Locked = true;
        ContentSourceExpectedLbl: Label 'exactly one of contentBase64 (or the alias content), storageCode with path, sourceTarget with sourceSystemId', Locked = true;
        BothInlineContentErr: Label 'Supply contentBase64 or content, not both.', Locked = true;
        BothInlineContentExpectedLbl: Label 'contentBase64 or content, not both', Locked = true;
        NoAttachmentKeyErr: Label 'Business Central does not know which field identifies a record in table %1, so an attachment cannot be keyed to it.', Comment = '%1 = table id, is-IS=Business Central veit ekki hvaða reitur auðkennir færslu í töflu %1 og því er ekki hægt að tengja viðhengi við hana.';
        AttachmentGoneErr: Label 'The attachment was removed while it was being processed.', Comment = 'is-IS=Viðhenginu var eytt á meðan verið var að vinna með það.';
        NoAttachmentKeyNextStepLbl: Label 'Attach the file to a record of a table that supports attachments, or have a developer subscribe to Document Attachment Mgmt.OnAfterTableHasNumberFieldPrimaryKey for this table.', Comment = 'is-IS=Hengdu skrána við færslu í töflu sem styður viðhengi eða láttu forritara gerast áskrifanda að Document Attachment Mgmt.OnAfterTableHasNumberFieldPrimaryKey fyrir þessa töflu.';

    /// <summary>Offloads an attachment's content to storage and clears it from the database.</summary>
    /// <param name="Argument">The message argument carrying <c>target</c>, <c>systemId</c>, <c>storageCode</c> and optional <c>folderPath</c>; receives the error response.</param>
    /// <param name="ResultData">Out: the success payload describing the offloaded file.</param>
    /// <returns>True when the attachment was offloaded; false when an error response was written.</returns>
    procedure Offload(var Argument: Record "Message Argument ori"; var ResultData: JsonObject): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
        Link: Record "Storage Attachment Link ori";
        TempBlob: Codeunit "Temp Blob";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        Target: Enum "Storage Attachment Target ori";
        RequestJson: JsonObject;
        RecSystemId: Guid;
        TableId: Integer;
        EntryNo: Integer;
        LineNo: Integer;
        FileName: Text;
        FolderPath: Text;
        Path: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        ReadTarget(Argument, RequestJson, 'target', Target);
        Reader.ReadGuid(Argument, RequestJson, 'systemId', true, RecSystemId);
        RequestMgt.ReadSetup(Argument, RequestJson, StorageSetup, Connector);
        Reader.ReadPath(Argument, RequestJson, 'folderPath', false, FolderPath);
        if Reader.RespondIfErrors(Argument) then
            exit(false);

        TableId := TableIdForTarget(Target);
        if not ReadAttachment(Target, RecSystemId, TempBlob, FileName, EntryNo, LineNo) then begin
            RespondRecordNotFound(Argument, TableId, Format(RecSystemId, 0, 4), 'systemId');
            exit(false);
        end;
        if Link.Get(TableId, RecSystemId) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, AlreadyOffloadedErr, 'systemId', Format(RecSystemId, 0, 4), NotOffloadedExpectedLbl, AlreadyOffloadedNextStepLbl);
            exit(false);
        end;
        if not TempBlob.HasValue() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NoContentErr, 'systemId', Format(RecSystemId, 0, 4), '', NoContentNextStepLbl);
            exit(false);
        end;

        Path := BuildPath(Target, TableId, RecSystemId, FileName, EntryNo, FolderPath);

        // The database writes happen first, then the upload last. The upload is the only step that
        // is not part of the transaction, so any failure before it rolls back cleanly (nothing
        // uploaded), and a failed upload rolls back the link insert and the content clear with it —
        // leaving no orphan blob in storage and the attachment content intact.
        Link.Init();
        Link."Table ID" := TableId;
        Link."Record System Id" := RecSystemId;
        Link."Storage Code" := StorageSetup."Code";
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
        ResultData.Add('storageCode', StorageSetup."Code");
        ResultData.Add('path', Path);
        ResultData.Add('contentLength', Link."Content Size");
        exit(true);
    end;

    /// <summary>Restores an offloaded attachment's content into the database and deletes the remote copy.</summary>
    /// <param name="Argument">The message argument carrying <c>target</c> and <c>systemId</c>; receives the error response.</param>
    /// <param name="ResultData">Out: the success payload describing the restored file.</param>
    /// <returns>True when the attachment was restored; false when an error response was written.</returns>
    procedure Restore(var Argument: Record "Message Argument ori"; var ResultData: JsonObject): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
        Link: Record "Storage Attachment Link ori";
        TempBlob: Codeunit "Temp Blob";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        Target: Enum "Storage Attachment Target ori";
        RequestJson: JsonObject;
        RecSystemId: Guid;
        TableId: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ReadTarget(Argument, RequestJson, 'target', Target);
        Reader.ReadGuid(Argument, RequestJson, 'systemId', true, RecSystemId);
        if Reader.RespondIfErrors(Argument) then
            exit(false);

        TableId := TableIdForTarget(Target);
        if not AttachmentExists(Target, RecSystemId) then begin
            RespondRecordNotFound(Argument, TableId, Format(RecSystemId, 0, 4), 'systemId');
            exit(false);
        end;
        Link.SetLoadFields("Storage Code", "Storage Path", "File Name");
        if not Link.Get(TableId, RecSystemId) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NotOffloadedErr, 'systemId', Format(RecSystemId, 0, 4), OffloadedExpectedLbl, NotOffloadedNextStepLbl);
            exit(false);
        end;
        // The connection is the one the link names, not a request value.
        if not RequestMgt.ResolveSetup(Argument, Link."Storage Code", '', StorageSetup, Connector) then begin
            Reader.RespondIfErrors(Argument);
            exit(false);
        end;

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
        exit(true);
    end;

    /// <summary>
    /// Creates an incoming-document attachment that points at a file already in storage (typically
    /// delivered through the chunked-upload message types). The attachment is created from the
    /// stored content, immediately linked, then its local content is cleared — so it ends up in the
    /// same transparently-served, born-offloaded state as <see cref="Offload"/> produces, without
    /// the file ever passing through the database from the caller.
    /// </summary>
    /// <param name="Argument">The message argument carrying <c>storageCode</c>, <c>path</c>, <c>fileName</c> and optional <c>incomingDocumentEntryNo</c>/<c>description</c>; receives the error response.</param>
    /// <param name="ResultData">Out: the success payload describing the new linked attachment.</param>
    /// <returns>True when the attachment was created; false when an error response was written.</returns>
    procedure CreateLinked(var Argument: Record "Message Argument ori"; var ResultData: JsonObject): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
        IncomingDocument: Record "Incoming Document";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
        Link: Record "Storage Attachment Link ori";
        TempBlob: Codeunit "Temp Blob";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        RequestJson: JsonObject;
        ContentInStream: InStream;
        StoragePath: Text;
        FileName: Text;
        Description: Text;
        Extension: Text;
        EntryNo: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        RequestMgt.ReadSetup(Argument, RequestJson, StorageSetup, Connector);
        Reader.ReadPath(Argument, RequestJson, 'path', true, StoragePath);
        Reader.ReadText(Argument, RequestJson, 'fileName', true, FileName);
        Reader.ReadText(Argument, RequestJson, 'description', false, Description);
        Reader.ReadNonNegativeInteger(Argument, RequestJson, 'incomingDocumentEntryNo', false, EntryNo);
        if Reader.RespondIfErrors(Argument) then
            exit(false);

        if EntryNo <> 0 then
            if not IncomingDocument.Get(EntryNo) then begin
                RespondRecordNotFound(Argument, Database::"Incoming Document", Format(EntryNo, 0, 9), 'incomingDocumentEntryNo');
                exit(false);
            end;
        if IsStorageFileLinked(StorageSetup."Code", StoragePath) then begin
            RespondPathAlreadyLinked(Argument, StorageSetup."Code", StoragePath);
            exit(false);
        end;
        Connector.GetFile(StorageSetup, StoragePath, TempBlob);
        if not TempBlob.HasValue() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NoStorageFileErr, StoragePath), 'path', StoragePath, '', NoStorageFileNextStepLbl);
            exit(false);
        end;

        if EntryNo = 0 then begin
            if Description = '' then
                Description := FileName;
            EntryNo := IncomingDocument.CreateIncomingDocument(CopyStr(Description, 1, 100), '');
            IncomingDocument.Get(EntryNo);
        end;

        Extension := FileExtensionOf(FileName);
        TempBlob.CreateInStream(ContentInStream);
        IncomingDocument.AddAttachmentFromStream(IncomingDocumentAttachment, FileName, Extension, ContentInStream);

        Link.Init();
        Link."Table ID" := Database::"Incoming Document Attachment";
        Link."Record System Id" := IncomingDocumentAttachment.SystemId;
        Link."Storage Code" := StorageSetup."Code";
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

        ResultData.Add('target', IncomingDocumentTok);
        ResultData.Add('incomingDocumentEntryNo', IncomingDocumentAttachment."Incoming Document Entry No.");
        ResultData.Add('lineNo', IncomingDocumentAttachment."Line No.");
        ResultData.Add('systemId', Format(IncomingDocumentAttachment.SystemId, 0, 4));
        ResultData.Add('storageCode', StorageSetup."Code");
        ResultData.Add('path', StoragePath);
        ResultData.Add('fileName', FileName);
        ResultData.Add('contentLength', Link."Content Size");
        exit(true);
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
    /// <param name="Argument">The message argument carrying the record address, <c>fileName</c> and one content source; receives the error response.</param>
    /// <param name="ResultData">Out: the success payload describing the new attachment.</param>
    /// <returns>True when the attachment was created; false when an error response was written.</returns>
    procedure CreateForRecord(var Argument: Record "Message Argument ori"; var ResultData: JsonObject): Boolean
    var
        DocumentAttachment: Record "Document Attachment";
        Link: Record "Storage Attachment Link ori";
        StorageSetup: Record "Storage Setup ori";
        TempBlob: Codeunit "Temp Blob";
        Reader: Codeunit "Storage Request Reader ori";
        RecordRef: RecordRef;
        Connector: Interface "Storage Connector ori";
        SourceTarget: Enum "Storage Attachment Target ori";
        RequestJson: JsonObject;
        SourceSystemId: Guid;
        FromStorage: Boolean;
        ContentInStream: InStream;
        FileName: Text;
        SourceFileName: Text;
        StoragePath: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        ReadRecordAddress(Argument, RequestJson, RecordRef);
        ReadContentSource(Argument, RequestJson, TempBlob, StorageSetup, Connector, StoragePath, SourceTarget, SourceSystemId, FromStorage);
        Reader.ReadText(Argument, RequestJson, 'fileName', false, FileName);
        if Reader.RespondIfErrors(Argument) then
            exit(false);

        if not LoadContent(Argument, TempBlob, StorageSetup, Connector, StoragePath, SourceTarget, SourceSystemId, FromStorage, SourceFileName) then
            exit(false);

        // fileName is optional only when copying an attachment that already carries one.
        if FileName = '' then
            FileName := SourceFileName;
        if FileName = '' then begin
            Reader.ReadText(Argument, RequestJson, 'fileName', true, FileName);
            Reader.RespondIfErrors(Argument);
            exit(false);
        end;

        TempBlob.CreateInStream(ContentInStream);
        DocumentAttachment.Init();
        DocumentAttachment.SaveAttachmentFromStream(ContentInStream, RecordRef, FileName);
        RaiseIfNoAttachmentKey(Argument, DocumentAttachment, RecordRef.Number());
        RecordRef.Close();

        if FromStorage then begin
            Link.Init();
            Link."Table ID" := Database::"Document Attachment";
            Link."Record System Id" := DocumentAttachment.SystemId;
            Link."Storage Code" := StorageSetup."Code";
            Link."Storage Path" := CopyStr(StoragePath, 1, MaxStrLen(Link."Storage Path"));
            Link."File Name" := CopyStr(FileName, 1, MaxStrLen(Link."File Name"));
            Link."Content Size" := TempBlob.Length();
            Link."Offloaded At" := CurrentDateTime();
            Link."Offloaded By" := UserSecurityId();
            Link.Insert(true);

            Clear(DocumentAttachment."Document Reference ID");
            DocumentAttachment.Modify(true);
        end;

        AddDocumentAttachmentResult(DocumentAttachment, TempBlob, FromStorage, ResultData);
        if FromStorage then begin
            ResultData.Add('storageCode', StorageSetup."Code");
            ResultData.Add('path', StoragePath);
        end;
        exit(true);
    end;

    /// <summary>Creates a document attachment from pre-assembled content (used by CommitToRecord).</summary>
    /// <param name="Argument">The message argument carrying the record address and optional <c>fileName</c>; receives the error response.</param>
    /// <param name="TempBlob">The assembled content.</param>
    /// <param name="SessionFileName">The file name given when the upload began; used when the request has none.</param>
    /// <param name="ResultData">Out: the success payload describing the new attachment.</param>
    /// <returns>True when the attachment was created; false when an error response was written.</returns>
    procedure CreateForRecordFromBlob(var Argument: Record "Message Argument ori"; var TempBlob: Codeunit "Temp Blob"; SessionFileName: Text; var ResultData: JsonObject): Boolean
    var
        DocumentAttachment: Record "Document Attachment";
        Reader: Codeunit "Storage Request Reader ori";
        RecordRef: RecordRef;
        RequestJson: JsonObject;
        ContentInStream: InStream;
        FileName: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        ReadRecordAddress(Argument, RequestJson, RecordRef);
        Reader.ReadText(Argument, RequestJson, 'fileName', SessionFileName = '', FileName);
        if FileName = '' then
            FileName := SessionFileName;
        if Reader.RespondIfErrors(Argument) then
            exit(false);

        TempBlob.CreateInStream(ContentInStream);
        DocumentAttachment.Init();
        DocumentAttachment.SaveAttachmentFromStream(ContentInStream, RecordRef, FileName);
        RaiseIfNoAttachmentKey(Argument, DocumentAttachment, RecordRef.Number());
        RecordRef.Close();

        AddDocumentAttachmentResult(DocumentAttachment, TempBlob, false, ResultData);
        exit(true);
    end;

    /// <summary>Creates an incoming document attachment from pre-assembled content (used by CommitToRecord).</summary>
    /// <param name="Argument">The message argument carrying optional <c>fileName</c>, <c>description</c> and <c>incomingDocumentEntryNo</c>; receives the error response.</param>
    /// <param name="TempBlob">The assembled content.</param>
    /// <param name="SessionFileName">The file name given when the upload began; used when the request has none.</param>
    /// <param name="ResultData">Out: the success payload describing the new attachment.</param>
    /// <returns>True when the attachment was created; false when an error response was written.</returns>
    procedure CreateIncomingFromBlob(var Argument: Record "Message Argument ori"; var TempBlob: Codeunit "Temp Blob"; SessionFileName: Text; var ResultData: JsonObject): Boolean
    var
        IncomingDocument: Record "Incoming Document";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
        Reader: Codeunit "Storage Request Reader ori";
        RequestJson: JsonObject;
        ContentInStream: InStream;
        FileName: Text;
        Description: Text;
        Extension: Text;
        EntryNo: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        Reader.ReadText(Argument, RequestJson, 'fileName', SessionFileName = '', FileName);
        if FileName = '' then
            FileName := SessionFileName;
        Reader.ReadText(Argument, RequestJson, 'description', false, Description);
        Reader.ReadNonNegativeInteger(Argument, RequestJson, 'incomingDocumentEntryNo', false, EntryNo);
        if Reader.RespondIfErrors(Argument) then
            exit(false);

        if EntryNo <> 0 then
            if not IncomingDocument.Get(EntryNo) then begin
                RespondRecordNotFound(Argument, Database::"Incoming Document", Format(EntryNo, 0, 9), 'incomingDocumentEntryNo');
                exit(false);
            end;
        if EntryNo = 0 then begin
            if Description = '' then
                Description := FileName;
            EntryNo := IncomingDocument.CreateIncomingDocument(CopyStr(Description, 1, 100), '');
            IncomingDocument.Get(EntryNo);
        end;

        Extension := FileExtensionOf(FileName);
        TempBlob.CreateInStream(ContentInStream);
        IncomingDocument.AddAttachmentFromStream(IncomingDocumentAttachment, FileName, Extension, ContentInStream);

        ResultData.Add('target', IncomingDocumentTok);
        ResultData.Add('incomingDocumentEntryNo', IncomingDocumentAttachment."Incoming Document Entry No.");
        ResultData.Add('lineNo', IncomingDocumentAttachment."Line No.");
        ResultData.Add('systemId', Format(IncomingDocumentAttachment.SystemId, 0, 4));
        ResultData.Add('fileName', FileName);
        ResultData.Add('contentLength', TempBlob.Length());
        ResultData.Add('offloaded', false);
        exit(true);
    end;

    /// <summary>
    /// Reads an attachment target (<c>DocumentAttachment</c> or <c>IncomingDocument</c>). A missing
    /// target adds <c>MissingParameter</c>; any other text adds <c>InvalidParameter</c>.
    /// </summary>
    /// <param name="Argument">The message argument that collects the problems.</param>
    /// <param name="RequestJson">The request JSON.</param>
    /// <param name="ParameterName">The JSON property to read.</param>
    /// <param name="Target">Out: the target.</param>
    /// <returns>True when the target is usable.</returns>
    procedure ReadTarget(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; var Target: Enum "Storage Attachment Target ori"): Boolean
    var
        Reader: Codeunit "Storage Request Reader ori";
        TargetText: Text;
    begin
        if not Reader.ReadText(Argument, RequestJson, ParameterName, true, TargetText) then
            exit(false);
        case TargetText of
            DocumentAttachmentTok:
                Target := Target::DocumentAttachment;
            IncomingDocumentTok:
                Target := Target::IncomingDocument;
            else begin
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(UnknownTargetErr, ParameterName, TargetText), ParameterName, TargetText, TargetExpectedLbl, '');
                exit(false);
            end;
        end;
        exit(true);
    end;

    /// <summary>
    /// Reads the table (<c>tableId</c> or <c>tableName</c>) and the record (<c>recordSystemId</c> or
    /// <c>no</c>) an attachment belongs to and positions <paramref name="RecordRef"/> on it.
    /// <c>recordSystemId</c> works for every table; <c>no</c> is the convenience path for master
    /// records, whose primary key is one code field. Problems are collected on the argument.
    /// </summary>
    local procedure ReadRecordAddress(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var RecordRef: RecordRef): Boolean
    var
        Reader: Codeunit "Storage Request Reader ori";
        FieldRef: FieldRef;
        KeyRef: KeyRef;
        RecSystemId: Guid;
        AttachmentNo: Code[20];
        TableId: Integer;
        TableParameter: Text;
        NoText: Text;
    begin
        if not ReadTableId(Argument, RequestJson, TableId, TableParameter) then begin
            // The record cannot be looked up without its table, but its identifiers can still be checked.
            Reader.ReadGuid(Argument, RequestJson, 'recordSystemId', false, RecSystemId);
            exit(false);
        end;

        RecordRef.Open(TableId);
        if not RecordRef.ReadPermission() then begin
            Argument.AddError("Bifrost Error Code ori"::PermissionDenied, StrSubstNo(ReadPermissionErr, TableId), TableParameter, Format(TableId, 0, 9), '', '');
            exit(false);
        end;

        if not Reader.ReadGuid(Argument, RequestJson, 'recordSystemId', false, RecSystemId) then
            exit(false);
        if not IsNullGuid(RecSystemId) then begin
            if RecordRef.GetBySystemId(RecSystemId) then
                exit(true);
            AddRecordNotFound(Argument, TableId, Format(RecSystemId, 0, 4), 'recordSystemId');
            exit(false);
        end;

        Reader.ReadText(Argument, RequestJson, 'no', false, NoText);
        if NoText = '' then begin
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, RecordRequiredErr, 'no', '', RecordExpectedLbl, '');
            exit(false);
        end;
        // Document Attachment's own key is a Code[20], so a longer identifier can never be stored.
        if StrLen(NoText) > MaxStrLen(AttachmentNo) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(RecordNoTooLongErr, NoText), 'no', NoText, RecordNoExpectedLbl, UseRecordSystemIdLbl);
            exit(false);
        end;
        KeyRef := RecordRef.KeyIndex(1);
        if KeyRef.FieldCount() <> 1 then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(CompositeKeyErr, TableId), 'no', NoText, '', UseRecordSystemIdLbl);
            exit(false);
        end;
        FieldRef := KeyRef.FieldIndex(1);
        if not (FieldRef.Type() in [FieldType::Code, FieldType::Text]) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(NonCodeKeyErr, TableId), 'no', NoText, '', UseRecordSystemIdLbl);
            exit(false);
        end;

        FieldRef.Value := NoText;
        if RecordRef.Find('=') then
            exit(true);
        AddRecordNotFound(Argument, TableId, NoText, 'no');
        exit(false);
    end;

    local procedure ReadTableId(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var TableId: Integer; var TableParameter: Text): Boolean
    var
        AllObjWithCaption: Record AllObjWithCaption;
        Reader: Codeunit "Storage Request Reader ori";
        TableName: Text;
    begin
        TableId := 0;
        TableParameter := 'tableId';
        if not Reader.ReadInteger(Argument, RequestJson, 'tableId', false, TableId) then
            exit(false);
        if TableId <> 0 then begin
            if AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Table, TableId) then
                exit(true);
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownTableErr, TableId), 'tableId', Format(TableId, 0, 9), '', UnknownTableNextStepLbl);
            exit(false);
        end;

        TableParameter := 'tableName';
        Reader.ReadText(Argument, RequestJson, 'tableName', false, TableName);
        if TableName = '' then begin
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, TableRequiredErr, 'tableId', '', TableExpectedLbl, '');
            exit(false);
        end;
        AllObjWithCaption.SetRange("Object Type", AllObjWithCaption."Object Type"::Table);
        AllObjWithCaption.SetRange("Object Name", CopyStr(TableName, 1, MaxStrLen(AllObjWithCaption."Object Name")));
        if AllObjWithCaption.FindFirst() then begin
            TableId := AllObjWithCaption."Object ID";
            exit(true);
        end;
        Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownTableNameErr, TableName), 'tableName', TableName, '', UnknownTableNextStepLbl);
        exit(false);
    end;

    /// <summary>
    /// Reads which of the three content sources the request names and checks that it names exactly
    /// one. Inline content is decoded here; the storage file and the source attachment are fetched
    /// by <see cref="LoadContent"/> once every request value has been read.
    /// </summary>
    local procedure ReadContentSource(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var TempBlob: Codeunit "Temp Blob"; var StorageSetup: Record "Storage Setup ori"; var Connector: Interface "Storage Connector ori"; var StoragePath: Text; var SourceTarget: Enum "Storage Attachment Target ori"; var SourceSystemId: Guid; var FromStorage: Boolean): Boolean
    var
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        HasContent: Boolean;
        HasContentBase64: Boolean;
        HasContentAlias: Boolean;
        HasStorage: Boolean;
        HasSource: Boolean;
        SourceCount: Integer;
    begin
        Clear(TempBlob);
        FromStorage := false;
        // contentBase64 is canonical; content remains an accepted alias. Both names in one request is an error.
        HasContentBase64 := RequestMgt.GetText(RequestJson, 'contentBase64') <> '';
        HasContentAlias := RequestMgt.GetText(RequestJson, 'content') <> '';
        if HasContentBase64 and HasContentAlias then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, BothInlineContentErr, 'content', '', BothInlineContentExpectedLbl, '');
            exit(false);
        end;
        HasContent := HasContentBase64 or HasContentAlias;
        HasStorage := (RequestMgt.GetText(RequestJson, 'storageCode') <> '') or (RequestMgt.GetText(RequestJson, 'path') <> '');
        HasSource := RequestMgt.GetText(RequestJson, 'sourceSystemId') <> '';
        if HasContent then
            SourceCount += 1;
        if HasStorage then
            SourceCount += 1;
        if HasSource then
            SourceCount += 1;
        if SourceCount <> 1 then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, ContentSourceErr, ContentSourceParameterTok, '', ContentSourceExpectedLbl, '');
            exit(false);
        end;

        if HasContent then begin
            if HasContentBase64 then
                exit(Reader.ReadBase64Content(Argument, RequestJson, 'contentBase64', true, TempBlob));
            exit(Reader.ReadBase64Content(Argument, RequestJson, 'content', true, TempBlob));
        end;

        if HasSource then begin
            ReadTarget(Argument, RequestJson, 'sourceTarget', SourceTarget);
            exit(Reader.ReadGuid(Argument, RequestJson, 'sourceSystemId', true, SourceSystemId));
        end;

        FromStorage := true;
        RequestMgt.ReadSetup(Argument, RequestJson, StorageSetup, Connector);
        exit(Reader.ReadPath(Argument, RequestJson, 'path', true, StoragePath));
    end;

    /// <summary>
    /// Fetches the content of the source <see cref="ReadContentSource"/> accepted: a file in storage
    /// (born offloaded) or an existing attachment. Inline content is already decoded. Answers the
    /// error itself and returns false when the source is not usable. <c>Connector</c> is passed by
    /// reference because it is never assigned for inline or copied content, and an unassigned
    /// interface cannot be passed by value.
    /// </summary>
    local procedure LoadContent(var Argument: Record "Message Argument ori"; var TempBlob: Codeunit "Temp Blob"; StorageSetup: Record "Storage Setup ori"; var Connector: Interface "Storage Connector ori"; StoragePath: Text; SourceTarget: Enum "Storage Attachment Target ori"; SourceSystemId: Guid; FromStorage: Boolean; var SourceFileName: Text): Boolean
    var
        SourceEntryNo: Integer;
        SourceLineNo: Integer;
    begin
        SourceFileName := '';
        if FromStorage then begin
            if IsStorageFileLinked(StorageSetup."Code", StoragePath) then begin
                RespondPathAlreadyLinked(Argument, StorageSetup."Code", StoragePath);
                exit(false);
            end;
            Connector.GetFile(StorageSetup, StoragePath, TempBlob);
            if TempBlob.HasValue() then
                exit(true);
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NoStorageFileErr, StoragePath), 'path', StoragePath, '', NoStorageFileNextStepLbl);
            exit(false);
        end;

        if IsNullGuid(SourceSystemId) then
            exit(true);
        // Reads through the transparent serve hooks, so a source that is itself offloaded works.
        if not ReadAttachment(SourceTarget, SourceSystemId, TempBlob, SourceFileName, SourceEntryNo, SourceLineNo) then begin
            RespondRecordNotFound(Argument, TableIdForTarget(SourceTarget), Format(SourceSystemId, 0, 4), 'sourceSystemId');
            exit(false);
        end;
        if TempBlob.HasValue() then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NoContentErr, 'sourceSystemId', Format(SourceSystemId, 0, 4), '', NoContentNextStepLbl);
        exit(false);
    end;

    /// <summary>
    /// Raises when the base application could not tell which field identifies the record, so the
    /// attachment it just inserted has an empty key. The raise rolls the insert back with the whole
    /// message, and the collected error still reaches the caller structured.
    /// </summary>
    local procedure RaiseIfNoAttachmentKey(var Argument: Record "Message Argument ori"; DocumentAttachment: Record "Document Attachment"; TableId: Integer)
    begin
        if DocumentAttachment."No." <> '' then
            exit;
        Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoAttachmentKeyErr, TableId), 'tableId', Format(TableId, 0, 9), '', NoAttachmentKeyNextStepLbl);
        Argument.RaiseCollectedErrors("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoAttachmentKeyErr, TableId));
    end;

    local procedure AddDocumentAttachmentResult(DocumentAttachment: Record "Document Attachment"; var TempBlob: Codeunit "Temp Blob"; Offloaded: Boolean; var ResultData: JsonObject)
    begin
        ResultData.Add('target', DocumentAttachmentTok);
        ResultData.Add('tableId', DocumentAttachment."Table ID");
        ResultData.Add('no', DocumentAttachment."No.");
        ResultData.Add('documentType', Format(DocumentAttachment."Document Type", 0, 9));
        ResultData.Add('lineNo', DocumentAttachment."Line No.");
        ResultData.Add('attachmentId', DocumentAttachment.ID);
        ResultData.Add('systemId', Format(DocumentAttachment.SystemId, 0, 4));
        ResultData.Add('fileName', ComposeFileName(DocumentAttachment."File Name", DocumentAttachment."File Extension"));
        ResultData.Add('contentLength', TempBlob.Length());
        ResultData.Add('offloaded', Offloaded);
    end;

    local procedure AddRecordNotFound(var Argument: Record "Message Argument ori"; TableId: Integer; Value: Text; ParameterName: Text)
    var
        TableCaption: Text;
    begin
        TableCaption := GetTableCaption(TableId);
        Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(RecordNotFoundErr, TableCaption, Value, ParameterName), ParameterName, Value, '', StrSubstNo(RecordNotFoundNextStepLbl, TableCaption));
    end;

    local procedure RespondRecordNotFound(var Argument: Record "Message Argument ori"; TableId: Integer; Value: Text; ParameterName: Text)
    var
        Reader: Codeunit "Storage Request Reader ori";
    begin
        AddRecordNotFound(Argument, TableId, Value, ParameterName);
        Reader.RespondIfErrors(Argument);
    end;

    local procedure RespondPathAlreadyLinked(var Argument: Record "Message Argument ori"; StorageCode: Code[20]; Path: Text)
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(PathAlreadyLinkedErr, Path, StorageCode), 'path', Path, UnlinkedExpectedLbl, PathAlreadyLinkedNextStepLbl);
    end;

    local procedure GetTableCaption(TableId: Integer): Text
    var
        RecordRef: RecordRef;
        TableCaption: Text;
    begin
        RecordRef.Open(TableId);
        TableCaption := RecordRef.Caption();
        RecordRef.Close();
        exit(TableCaption);
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

    /// <summary>Tells whether a storage file backs an attachment, so it must not be deleted directly.</summary>
    /// <param name="StorageCode">The storage connection that holds the file.</param>
    /// <param name="Path">The storage path.</param>
    /// <returns>True when an attachment link points at the file.</returns>
    procedure IsStorageFileLinked(StorageCode: Code[20]; Path: Text): Boolean
    var
        Link: Record "Storage Attachment Link ori";
    begin
        exit(FindLinkedStorageFile(StorageCode, Path, Link));
    end;

    /// <summary>Tells whether any file inside a storage directory backs an attachment.</summary>
    /// <param name="StorageCode">The storage connection that holds the directory.</param>
    /// <param name="DirectoryPath">The storage directory.</param>
    /// <returns>True when an attachment link points at a file inside the directory.</returns>
    procedure IsStorageDirectoryLinked(StorageCode: Code[20]; DirectoryPath: Text): Boolean
    var
        Link: Record "Storage Attachment Link ori";
    begin
        exit(FindLinkedStoragePathInDirectory(StorageCode, DirectoryPath, Link));
    end;

    /// <summary>
    /// Tells whether the current user may update the link rows of a linked file that is about to
    /// be moved. A file that no attachment is linked to can always be moved.
    /// </summary>
    /// <param name="StorageCode">The storage connection that holds the file.</param>
    /// <param name="SourcePath">The current storage path.</param>
    /// <param name="BlockReason">Out: why the links cannot be updated.</param>
    /// <returns>True when the file can be moved.</returns>
    procedure CanUpdateLinksOf(StorageCode: Code[20]; SourcePath: Text; var BlockReason: Text): Boolean
    var
        Link: Record "Storage Attachment Link ori";
    begin
        BlockReason := '';
        if not FindLinkedStorageFile(StorageCode, SourcePath, Link) then
            exit(true);
        repeat
            BlockReason := LinkUpdateBlockReason(Link);
            if BlockReason <> '' then
                exit(false);
        until Link.Next() = 0;
        exit(true);
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

    local procedure LinkUpdateBlockReason(var Link: Record "Storage Attachment Link ori"): Text
    var
        LinkedRecordRef: RecordRef;
        CanWrite: Boolean;
    begin
        if not Link.WritePermission() then
            exit(LinkPermissionErr);
        LinkedRecordRef.Open(Link."Table ID");
        CanWrite := LinkedRecordRef.WritePermission();
        LinkedRecordRef.Close();
        if not CanWrite then
            exit(StrSubstNo(TargetPermissionErr, Link."Table ID"));
        exit('');
    end;

    local procedure ReadAttachment(Target: Enum "Storage Attachment Target ori"; RecSystemId: Guid; var TempBlob: Codeunit "Temp Blob"; var FileName: Text; var EntryNo: Integer; var LineNo: Integer): Boolean
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
                        exit(false);
                    FileName := ComposeFileName(DocumentAttachment."File Name", DocumentAttachment."File Extension");
                    DocumentAttachment.GetAsTempBlob(TempBlob);
                end;
            Target::IncomingDocument:
                begin
                    if not IncomingDocumentAttachment.GetBySystemId(RecSystemId) then
                        exit(false);
                    FileName := ComposeFileName(IncomingDocumentAttachment.Name, IncomingDocumentAttachment."File Extension");
                    EntryNo := IncomingDocumentAttachment."Incoming Document Entry No.";
                    LineNo := IncomingDocumentAttachment."Line No.";
                    IncomingDocumentAttachment.GetContent(TempBlob);
                end;
        end;
        exit(true);
    end;

    local procedure AttachmentExists(Target: Enum "Storage Attachment Target ori"; RecSystemId: Guid): Boolean
    var
        DocumentAttachment: Record "Document Attachment";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
    begin
        case Target of
            Target::DocumentAttachment:
                begin
                    DocumentAttachment.SetLoadFields(ID);
                    exit(DocumentAttachment.GetBySystemId(RecSystemId));
                end;
            Target::IncomingDocument:
                begin
                    IncomingDocumentAttachment.SetLoadFields("Line No.");
                    exit(IncomingDocumentAttachment.GetBySystemId(RecSystemId));
                end;
        end;
        exit(false);
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
                        Error(AttachmentGoneErr);
                    Clear(DocumentAttachment."Document Reference ID");
                    DocumentAttachment.Modify(true);
                end;
            Target::IncomingDocument:
                begin
                    if not IncomingDocumentAttachment.GetBySystemId(RecSystemId) then
                        Error(AttachmentGoneErr);
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
                        Error(AttachmentGoneErr);
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
                        Error(AttachmentGoneErr);
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

    local procedure TargetName(Target: Enum "Storage Attachment Target ori"): Text
    begin
        case Target of
            Target::DocumentAttachment:
                exit(DocumentAttachmentTok);
            Target::IncomingDocument:
                exit(IncomingDocumentTok);
        end;
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
