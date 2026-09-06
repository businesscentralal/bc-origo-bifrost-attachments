namespace Origo.Bifrost.Attachments;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
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
        if IsHandled then
            exit;
        if not Link.Get(Database::"Document Attachment", DocumentAttachment.SystemId) then
            exit;
        AttachmentMgt.FetchContent(Link."Storage Code", Link."Storage Path", TempBlob);
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Document Attachment", 'OnBeforeExportToStream', '', false, false)]
    local procedure ServeDocumentAttachmentToStream(var DocumentAttachment: Record "Document Attachment"; var AttachmentOutStream: OutStream; var IsHandled: Boolean)
    var
        Link: Record "Storage Attachment Link ori";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        TempBlob: Codeunit "Temp Blob";
        ContentInStream: InStream;
    begin
        if IsHandled then
            exit;
        if not Link.Get(Database::"Document Attachment", DocumentAttachment.SystemId) then
            exit;
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
        if IsHandled then
            exit;
        if not Link.Get(Database::"Document Attachment", DocumentAttachment.SystemId) then
            exit;
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
}
