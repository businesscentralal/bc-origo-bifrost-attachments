namespace Origo.Bifrost.Attachments;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using System.Reflection;
using System.Utilities;

/// <summary>
/// Makes offloaded attachment content transparent to Business Central. Subscribes to the
/// attachment tables' content-read hooks and, when a record is offloaded (a
/// <c>Bifrost Storage Attachment Link</c> row exists), serves the content from external storage so
/// existing processes behave as if the file were still local. Also cleans up the remote copy
/// and the link when an attachment record is deleted.
/// </summary>
codeunit 10035636 "Storage Attachment Subscr ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Incoming Document Attachment", 'OnGetBinaryContent', '', false, false)]
    local procedure ServeIncomingDocumentContent(var Sender: Record "Incoming Document Attachment"; var TempBlob: Codeunit "Temp Blob"; IncomingDocumentEntryNo: Integer)
    var
        Link: Record "Storage Attachment Link ori";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
    begin
        if TempBlob.HasValue() then
            exit;
        Link.SetLoadFields("Storage Code", "Storage Path");
        if not Link.Get(Database::"Incoming Document Attachment", Sender.SystemId) then
            exit;
        AttachmentMgt.FetchContent(Link."Storage Code", Link."Storage Path", TempBlob);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Document Attachment", 'OnBeforeGetAsTempBlob', '', false, false)]
    local procedure ServeDocumentAttachmentAsTempBlob(var DocumentAttachment: Record "Document Attachment"; var TempBlob: Codeunit "Temp Blob"; var IsHandled: Boolean)
    var
        Link: Record "Storage Attachment Link ori";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
    begin
        // A Bifrost link owns the bytes. Microsoft's external-storage module also subscribes and,
        // because the native mirror sets Stored Externally, claims the read and looks in its own account.
        // Serve the linked file even when that subscriber already set IsHandled.
        Link.SetLoadFields("Storage Code", "Storage Path");
        if not Link.Get(Database::"Document Attachment", DocumentAttachment.SystemId) then begin
            if IsHandled then
                LogReadAlreadyHandled(DocumentAttachment.SystemId);
            exit;
        end;
        KeepMicrosoftModuleFromClaimingRead(DocumentAttachment);
        AttachmentMgt.FetchContent(Link."Storage Code", Link."Storage Path", TempBlob);
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Document Attachment", 'OnBeforeModifyEvent', '', false, false)]
    local procedure RestoreStoredInternallyBeforeWrite(var Rec: Record "Document Attachment"; var xRec: Record "Document Attachment"; RunTrigger: Boolean)
    begin
        // The read subscribers mark Stored Internally on the caller's record so Microsoft's
        // module does not claim the bytes. A later Modify, such as Document Attachment Details
        // saving Rec after HasContent, would persist that mark next to Stored Externally and
        // empty media. Put the persisted false back before the write. Rows without a Bifrost
        // link, including Microsoft's own offloads, are left alone.
        // Modify(false) still writes the caller's fields, so a false RunTrigger does not skip the restore.
        // Rename writes only the primary key and does not run OnModify, so it cannot persist the mark.
        if Rec.IsTemporary() or xRec.IsTemporary() then
            exit;
        if (not RunTrigger) and (xRec.SystemId <> Rec.SystemId) then
            exit;
        RestorePersistedStoredInternally(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Document Attachment", 'OnBeforeInsertEvent', '', false, false)]
    local procedure RestoreStoredInternallyBeforeInsert(var Rec: Record "Document Attachment"; RunTrigger: Boolean)
    begin
        // TransferFields from a record just marked by HasContent copies Stored Internally onto the new row.
        // Insert assigns a new SystemId before this event, so the copy is recognized by the mirrored external path of the existing Bifrost link.
        // Insert(false) still writes that copy. Rename is safe: it writes only the primary key and does not run OnInsert or OnModify.
        if Rec.IsTemporary() then
            exit;
        RestorePersistedStoredInternally(Rec);
    end;

    local procedure RestorePersistedStoredInternally(var Rec: Record "Document Attachment")
    var
        Link: Record "Storage Attachment Link ori";
        RecRef: RecordRef;
        StoredExternallyFld: FieldRef;
        ExternalFilePathFld: FieldRef;
        StoredInternallyFld: FieldRef;
        StoredExternally: Boolean;
        StoredInternally: Boolean;
    begin
        RecRef.GetTable(Rec);
        if not RecRef.FieldExist(8750) or not RecRef.FieldExist(8752) or not RecRef.FieldExist(8753) then begin
            RecRef.Close();
            exit;
        end;
        StoredExternallyFld := RecRef.Field(8750);
        ExternalFilePathFld := RecRef.Field(8752);
        StoredInternallyFld := RecRef.Field(8753);
        StoredExternally := StoredExternallyFld.Value;
        StoredInternally := StoredInternallyFld.Value;
        if StoredExternally and StoredInternally and (Format(ExternalFilePathFld.Value) <> '') then
            if Link.Get(Database::"Document Attachment", Rec.SystemId) or MirroredPathHasBifrostLink(Format(ExternalFilePathFld.Value)) then
                if TryClearStoredInternally(StoredInternallyFld) then
                    RecRef.SetTable(Rec)
                else
                    ClearLastError();
        RecRef.Close();
    end;

    local procedure MirroredPathHasBifrostLink(ExternalPath: Text): Boolean
    var
        Link: Record "Storage Attachment Link ori";
        StorageCode: Code[20];
        StoragePath: Text;
        ColonAt: Integer;
    begin
        // Field 8752 is stored as "<storage code>:<storage path>", matching Storage Attachment Link ori.
        ColonAt := StrPos(ExternalPath, ':');
        if ColonAt <= 1 then
            exit(false);
        StorageCode := CopyStr(CopyStr(ExternalPath, 1, ColonAt - 1), 1, MaxStrLen(StorageCode));
        StoragePath := CopyStr(ExternalPath, ColonAt + 1);
        if (StorageCode = '') or (StoragePath = '') then
            exit(false);
        Link.SetRange("Table ID", Database::"Document Attachment");
        Link.SetRange("Storage Code", StorageCode);
        Link.SetRange("Storage Path", CopyStr(StoragePath, 1, MaxStrLen(Link."Storage Path")));
        exit(not Link.IsEmpty());
    end;

    [EventSubscriber(ObjectType::Table, Database::"Document Attachment", 'OnBeforeExportToStream', '', false, false)]
    local procedure ServeDocumentAttachmentToStream(var DocumentAttachment: Record "Document Attachment"; var AttachmentOutStream: OutStream; var IsHandled: Boolean)
    var
        Link: Record "Storage Attachment Link ori";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        TempBlob: Codeunit "Temp Blob";
        ContentInStream: InStream;
    begin
        Link.SetLoadFields("Storage Code", "Storage Path");
        if not Link.Get(Database::"Document Attachment", DocumentAttachment.SystemId) then begin
            if IsHandled then
                LogReadAlreadyHandled(DocumentAttachment.SystemId);
            exit;
        end;
        KeepMicrosoftModuleFromClaimingRead(DocumentAttachment);
        AttachmentMgt.FetchContent(Link."Storage Code", Link."Storage Path", TempBlob);
        TempBlob.CreateInStream(ContentInStream);
        CopyStream(AttachmentOutStream, ContentInStream);
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Document Attachment", 'OnBeforeHasContent', '', false, false)]
    local procedure ReportOffloadedDocumentAttachmentHasContent(var DocumentAttachment: Record "Document Attachment"; var AttachmentIsAvailable: Boolean; var IsHandled: Boolean)
    var
        Link: Record "Storage Attachment Link ori";
    begin
        // Offloaded attachments have no local media, but the file is still available from storage,
        // so the UI must keep treating them as having content (download/preview stay enabled).
        Link.SetLoadFields("Storage Code");
        if not Link.Get(Database::"Document Attachment", DocumentAttachment.SystemId) then begin
            if IsHandled then
                LogReadAlreadyHandled(DocumentAttachment.SystemId);
            exit;
        end;
        KeepMicrosoftModuleFromClaimingRead(DocumentAttachment);
        AttachmentIsAvailable := true;
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Incoming Document Attachment", 'OnAfterDeleteEvent', '', false, false)]
    local procedure CleanupIncomingDocumentAttachment(var Rec: Record "Incoming Document Attachment"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        RemoveLink(Database::"Incoming Document Attachment", Rec.SystemId);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Document Attachment", 'OnAfterDeleteEvent', '', false, false)]
    local procedure CleanupDocumentAttachment(var Rec: Record "Document Attachment"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        RemoveLink(Database::"Document Attachment", Rec.SystemId);
    end;

    local procedure RemoveLink(TableId: Integer; RecSystemId: Guid)
    var
        Link: Record "Storage Attachment Link ori";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
    begin
        Link.SetLoadFields("Storage Code", "Storage Path");
        if not Link.Get(TableId, RecSystemId) then
            exit;
        if not TryDeleteRemote(AttachmentMgt, Link."Storage Code", Link."Storage Path") then
            ClearLastError();
        Link.Delete(true);
    end;

    [TryFunction]
    local procedure TryDeleteRemote(var AttachmentMgt: Codeunit "Storage Attachment Mgt ori"; StorageCode: Code[20]; Path: Text)
    begin
        AttachmentMgt.DeleteRemote(StorageCode, Path);
    end;

    local procedure KeepMicrosoftModuleFromClaimingRead(var DocumentAttachment: Record "Document Attachment")
    var
        RecRef: RecordRef;
        StoredInternallyFld: FieldRef;
    begin
        // Field 8753 is Stored Internally on External Storage - Document Attachments.
        // That module claims the read when Stored Externally is set and Stored Internally is not,
        // and it does not look at IsHandled. The native mirror sets exactly that pair.
        // Marking the in-memory record internally stored makes that subscriber leave the read alone.
        // RestorePersistedStoredInternally puts the persisted false back before Modify or Insert.
        RecRef.GetTable(DocumentAttachment);
        if not RecRef.FieldExist(8753) then begin
            RecRef.Close();
            exit;
        end;
        StoredInternallyFld := RecRef.Field(8753);
        if TryMarkStoredInternally(StoredInternallyFld) then
            RecRef.SetTable(DocumentAttachment)
        else
            ClearLastError();
        RecRef.Close();
    end;

    [TryFunction]
    local procedure TryMarkStoredInternally(var StoredInternallyFld: FieldRef)
    begin
        StoredInternallyFld.Value := true;
    end;

    [TryFunction]
    local procedure TryClearStoredInternally(var StoredInternallyFld: FieldRef)
    begin
        StoredInternallyFld.Value := false;
    end;

    local procedure LogReadAlreadyHandled(RecSystemId: Guid)
    begin
        Session.LogMessage('BFA-EXTSTOR-02', 'Document Attachment read already handled before Bifrost subscriber ran.', Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'systemId', Format(RecSystemId, 0, 4));
    end;
}
