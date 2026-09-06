namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;

/// <summary>
/// Adds an in-memory <c>Mock</c> backend to the <c>Bifrost Storage Type</c> enum so
/// the connector pipeline can be exercised in tests without a live storage account.
/// </summary>
enumextension 96200 "Storage Type Test" extends "Storage Type ori"
{
    /// <summary>In-memory test backend backed by <c>Bifrost Storage Mock State</c>.</summary>
    value(96200; Mock)
    {
        Caption = 'Mock', Locked = true;
        Implementation = "Storage Connector ori" = "Storage Mock Impl";
    }
}
