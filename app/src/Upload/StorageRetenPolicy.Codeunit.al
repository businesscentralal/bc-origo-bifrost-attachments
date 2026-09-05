namespace Origo.Bifrost.Hnitbjorg;

using System.DataAdministration;

/// <summary>
/// Registers the chunked-upload session table with the Business Central retention policy
/// framework and ships an enabled default policy. Sessions that are abandoned before they are
/// committed (or whose committed rows linger) are pruned automatically, and their chunks go with
/// them through the session's <c>OnDelete</c> cascade — so no orphaned upload state or chunk
/// blobs accumulate.
/// </summary>
codeunit 10035664 "Storage Reten. Policy ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reten. Pol. Allowed Tables", 'OnRefreshAllowedTables', '', false, false)]
    local procedure AddUploadSessionToAllowedTables()
    var
        UploadSession: Record "Storage Upload Session ori";
        RetenPolAllowedTables: Codeunit "Reten. Pol. Allowed Tables";
        RecRef: RecordRef;
        RetentionPeriod: Enum "Retention Period Enum";
        TableFilters: JsonArray;
    begin
        if RetenPolAllowedTables.IsAllowedTable(Database::"Storage Upload Session ori") then
            exit;
        RecRef.GetTable(UploadSession);
        RetenPolAllowedTables.AddTableFilterToJsonArray(
            TableFilters, RetentionPeriod::"1 Week", UploadSession.FieldNo(SystemCreatedAt), true, false, RecRef);
        RetenPolAllowedTables.AddAllowedTable(
            Database::"Storage Upload Session ori", UploadSession.FieldNo(SystemCreatedAt), TableFilters);
    end;
}
