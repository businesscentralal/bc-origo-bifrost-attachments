namespace Origo.Bifrost.Attachments;

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
/// <c>Data Exch.</c> is write-restricted as well. The dedicated import writers arrive in a
/// later phase; the hint already names them so generic <c>Data.Records.Set</c> cannot insert
/// audit rows ahead of that.
/// </summary>
codeunit 10035663 "Storage Data Restriction ori"
{
    Access = Internal;

    var
        DataExchWriteHintTxt: Label 'DataExchange.Import.Run / Storage.Upload.CommitToDataExchange', Locked = true;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnAfterIsTableReadRestrictedForDataRecords', '', false, false)]
    local procedure RestrictUploadTablesFromRead(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if IsUploadTable(TableNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnAfterIsTableWriteRestrictedForDataRecords', '', false, false)]
    local procedure RestrictUploadTablesFromWrite(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if IsUploadTable(TableNo) or IsStorageSetupTable(TableNo) or IsDataExchTable(TableNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnGetDedicatedMessageTypeHintForWrite', '', false, false)]
    local procedure HintDataExchWrite(TableNo: Integer; var Hint: Text)
    begin
        if IsDataExchTable(TableNo) then
            Hint := DataExchWriteHintTxt;
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
        exit(TableNo = Database::"Data Exch.");
    end;
}
