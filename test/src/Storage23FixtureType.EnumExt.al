namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;

/// <summary>Test-only durable fixture backend for self-seeded MCP verification in owned environments.</summary>
enumextension 96250 "Storage 23 Fixture Type ori" extends "Storage Type ori"
{
    /// <summary>Stores only owned test bytes in the test app, without an external account.</summary>
    value(96250; "MCP Fixture 23")
    {
        Caption = 'MCP Fixture 23', Locked = true;
        Implementation = "Storage Connector ori" = "Storage 23 Fixture Impl ori";
    }
}
