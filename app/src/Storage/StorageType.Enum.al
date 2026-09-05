namespace Origo.Bifrost.Hnitbjorg;

/// <summary>
/// Selects the <see cref="Interface.StorageConnector"/> implementation used to carry out
/// a storage action for a <c>Bifrost Storage Setup</c> row. The production value
/// <c>External File Storage</c> delegates to the Business Central
/// <c>External File Storage</c> facade (Azure Blob, Azure File Share, SharePoint). The
/// enum is extensible so the test app can add a <c>Mock</c> in-memory backend.
/// </summary>
enum 10035636 "Storage Type ori" implements "Storage Connector ori"
{
    Extensible = true;
    Caption = 'Bifrost Storage Type', Comment = 'is-IS=Tegund Bifröst geymslu';

    /// <summary>
    /// Routes every storage action through the Business Central <c>External File Storage</c>
    /// facade, using the connector and file account registered on the setup row. Supports all
    /// in-box connectors (Azure Blob, Azure File Share, SharePoint).
    /// </summary>
    value(0; "External File Storage")
    {
        Caption = 'External File Storage', Comment = 'is-IS=Ytri skráageymsla';
        Implementation = "Storage Connector ori" = "Storage Ext File Impl ori";
    }
}
