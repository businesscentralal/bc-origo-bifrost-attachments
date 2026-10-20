namespace Origo.Bifrost.Attachments;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using Origo.Bifrost;
using System.IO;

/// <summary>
/// Blocks upload-internal and storage-setup tables from the generic <c>Data.Records.*</c>
/// message types.
///
/// Upload sessions/chunks are openly usable through the dedicated <c>Storage.Upload.*</c>
/// types (their <c>InherentPermissions</c> grant every user the needed rights), but the
/// generic data API must never read or write them — that would let a caller see another
/// user's in-flight chunks or tamper with sessions, bypassing the per-user isolation in
/// <see cref="Codeunit.StorageUploadMgt"/>.
///
/// <c>Storage Setup ori</c> is write-restricted (read stays allowed) so connector binding,
/// account id and base-path changes only happen through the setup UX/logic, not ad-hoc
/// generic writes.
///
/// <c>Data Exch.</c> and <c>Data Exch. Field</c> are write-restricted as well: entries and their
/// parsed fields are written by <c>DataExchange.Import.Run</c> and
/// <c>Storage.Upload.CommitToDataExchange</c>, which the write hint names.
///
/// The definition tables (<c>Data Exch. Def</c>, line, column, mapping and field mapping) are
/// write-restricted and point at <c>DataExchange.Definition.Import</c> and
/// <c>DataExchange.Definition.Delete</c>. <c>DataExch Entry Link ori</c> is written only by the Data
/// Exchange types and points at <c>DataExchange.Entry.Delete</c>.
///
/// <c>Storage Attachment Link ori</c> is write-restricted the same way. Reads stay allowed
/// for audits. Legitimate rows are written by the attachment message types named in the
/// write hint.
///
/// <c>Data Exchange Type</c> rows are write-restricted and point at <c>DataExchange.Type.Set</c>.
/// <c>Incoming Document."Data Exchange Type"</c> is field-restricted and points at
/// <c>Storage.Upload.CommitToRecord / DataExchange.Type.Set</c>. The rest of Incoming Document
/// stays writable through the generic data types.
/// </summary>
codeunit 10035195 "Storage Data Restriction ori"
{
    Access = Internal;

    var
        DataExchWriteHintTxt: Label 'DataExchange.Import.Run / Storage.Upload.CommitToDataExchange', Locked = true;
        LinkWriteHintTxt: Label 'Storage.Attachment.Offload / Storage.Attachment.CreateLinked / Storage.Attachment.CreateForRecord', Locked = true;
        TypeSetHintTxt: Label 'DataExchange.Type.Set', Locked = true;
        IncomingTypeFieldHintTxt: Label 'Storage.Upload.CommitToRecord / DataExchange.Type.Set', Locked = true;
        DefinitionWriteHintTxt: Label 'DataExchange.Definition.Import / DataExchange.Definition.Delete', Locked = true;
        EntryLinkWriteHintTxt: Label 'DataExchange.Entry.Delete', Locked = true;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnAfterIsTableReadRestrictedForDataRecords', '', false, false)]
    local procedure RestrictUploadTablesFromRead(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if IsUploadTable(TableNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnAfterIsTableWriteRestrictedForDataRecords', '', false, false)]
    local procedure RestrictUploadTablesFromWrite(TableNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    begin
        // Foundation 28.0.3.530 passes Force. A permission-granted force does not reopen these tables.
        if IsProtectedTable(TableNo) then
            IsRestricted := true
        else
            if Force then
                exit;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnGetDedicatedMessageTypeHintForWrite', '', false, false)]
    local procedure HintDataExchWrite(TableNo: Integer; var Hint: Text)
    begin
        if IsDataExchTable(TableNo) then
            Hint := DataExchWriteHintTxt;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnGetDedicatedMessageTypeHintForWrite', '', false, false)]
    local procedure HintDefinitionWrite(TableNo: Integer; var Hint: Text)
    begin
        if IsDefinitionTable(TableNo) then
            Hint := DefinitionWriteHintTxt;
        if TableNo = Database::"DataExch Entry Link ori" then
            Hint := EntryLinkWriteHintTxt;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnGetDedicatedMessageTypeHintForWrite', '', false, false)]
    local procedure HintAttachmentLinkWrite(TableNo: Integer; var Hint: Text)
    begin
        if IsAttachmentLinkTable(TableNo) then
            Hint := LinkWriteHintTxt;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnGetDedicatedMessageTypeHintForWrite', '', false, false)]
    local procedure HintDataExchangeTypeWrite(TableNo: Integer; var Hint: Text)
    begin
        if IsDataExchangeTypeTable(TableNo) then
            Hint := TypeSetHintTxt;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnGetDedicatedMessageTypeHintForField', '', false, false)]
    local procedure HintIncomingDocumentDataExchangeTypeField(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    begin
        if (TableNo = Database::"Incoming Document") and (FieldNo = IncomingDocumentDataExchangeTypeFieldNo()) then
            Hint := IncomingTypeFieldHintTxt;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnAfterIsFieldWriteRestrictedForDataRecords', '', false, false)]
    local procedure RestrictNativeExternalStorFieldsFromWrite(TableNo: Integer; FieldNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    begin
        // Foundation 28.0.3.530 passes Force. A permission-granted force does not reopen these fields.
        if (TableNo = Database::"Document Attachment") and (FieldNo in [8750, 8751, 8752, 8753]) then
            IsRestricted := true;
        if (TableNo = Database::"Incoming Document") and (FieldNo = IncomingDocumentDataExchangeTypeFieldNo()) then
            IsRestricted := true;
        if Force and IsRestricted then
            IsRestricted := true;
    end;

    local procedure IsProtectedTable(TableNo: Integer): Boolean
    begin
        exit(IsUploadTable(TableNo) or IsStorageSetupTable(TableNo) or IsDataExchTable(TableNo) or IsAttachmentLinkTable(TableNo) or IsDataExchangeTypeTable(TableNo) or
            IsDefinitionTable(TableNo) or (TableNo = Database::"DataExch Entry Link ori"));
    end;

    local procedure IsUploadTable(TableNo: Integer): Boolean
    begin
        exit(TableNo in [Database::"Storage Upload Session ori", Database::"Storage Upload Chunk ori"]);
    end;

    local procedure IsStorageSetupTable(TableNo: Integer): Boolean
    begin
        exit(TableNo = Database::"Storage Setup ori");
    end;

    local procedure IsDataExchTable(TableNo: Integer): Boolean
    begin
        exit(TableNo in [Database::"Data Exch.", Database::"Data Exch. Field"]);
    end;

    local procedure IsDefinitionTable(TableNo: Integer): Boolean
    begin
        exit(TableNo in [Database::"Data Exch. Def", Database::"Data Exch. Line Def", Database::"Data Exch. Column Def", Database::"Data Exch. Mapping", Database::"Data Exch. Field Mapping"]);
    end;

    local procedure IsAttachmentLinkTable(TableNo: Integer): Boolean
    begin
        exit(TableNo = Database::"Storage Attachment Link ori");
    end;

    local procedure IsDataExchangeTypeTable(TableNo: Integer): Boolean
    begin
        exit(TableNo = Database::"Data Exchange Type");
    end;

    local procedure IncomingDocumentDataExchangeTypeFieldNo(): Integer
    var
        IncomingDocument: Record "Incoming Document";
    begin
        exit(IncomingDocument.FieldNo("Data Exchange Type"));
    end;
}
