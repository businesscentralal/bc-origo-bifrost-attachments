namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

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
/// </summary>
codeunit 10035663 "Storage Data Restriction ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnAfterIsTableReadRestrictedForDataRecords', '', false, false)]
    local procedure RestrictUploadTablesFromRead(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if IsUploadTable(TableNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnAfterIsTableWriteRestrictedForDataRecords', '', false, false)]
    local procedure RestrictUploadTablesFromWrite(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if IsUploadTable(TableNo) or IsStorageSetupTable(TableNo) then
            IsRestricted := true;
    end;

    local procedure IsUploadTable(TableNo: Integer): Boolean
    begin
        exit(TableNo in [Database::"Storage Upload Session ori", Database::"Storage Upload Chunk ori"]);
    end;

    local procedure IsStorageSetupTable(TableNo: Integer): Boolean
    begin
        exit(TableNo = Database::"Storage Setup ori");
    end;
}
