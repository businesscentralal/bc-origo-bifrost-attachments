namespace Origo.Bifrost.Attachments;

/// <summary>Optional guarantee for connectors that can safely move files backing attachment links.</summary>
/// <remarks>Connectors without this interface remain valid storage connectors; linked file moves are refused.</remarks>
interface "Storage Linked Move ori"
{
    /// <summary>Reports whether a move preserves the source on every failure and has no ambiguous remote outcome.</summary>
    /// <returns>True only when every failed move preserves the source and its outcome is known. An extra destination copy may require explicit cleanup; filesystem rollback is not promised.</returns>
    procedure SupportsLinkedMove(): Boolean

}
