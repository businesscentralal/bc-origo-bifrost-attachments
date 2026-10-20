namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;

/// <summary>Explicit test-only persisted storage for isolated MCP checks.</summary>
enumextension 96261 "Storage MCP Type ori" extends "Storage Type ori"
{
    value(96261; "MCP Fixture")
    {
        Caption = 'MCP Fixture', Locked = true;
        Implementation = "Storage Connector ori" = "Storage MCP Connector ori";
    }
}
