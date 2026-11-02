namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;

/// <summary>Loopback external storage for owned-container MCP acceptance.</summary>
enumextension 96266 "Storage HTTP Fixture Type ori" extends "Storage Type ori"
{
    value(96266; "MCP Loopback 168")
    {
        Caption = 'MCP Loopback 168', Locked = true;
        Implementation = "Storage Connector ori" = "Storage HTTP Fixture ori";
    }
}
