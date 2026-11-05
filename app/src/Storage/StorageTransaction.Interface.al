namespace Origo.Bifrost.Attachments;

/// <summary>Optional capability for connectors whose writes participate in the caller's database transaction.</summary>
interface "Storage Transaction ori"
{
    /// <summary>Reports that connector writes must run outside TryFunctions and roll back with the caller.</summary>
    /// <returns>True for a transactional database connector.</returns>
    procedure WritesInTransaction(): Boolean
}
