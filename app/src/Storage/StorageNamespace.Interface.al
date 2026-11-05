namespace Origo.Bifrost.Attachments;

/// <summary>Optional namespace identity for connectors whose connections do not share a registered account.</summary>
interface "Storage Namespace ori"
{
    /// <summary>Identifies the physical file namespace used by a connection in the current company.</summary>
    /// <returns>A stable identity equal only for connections that share file content.</returns>
    procedure GetNamespace(StorageSetup: Record "Storage Setup ori"): Text
}
