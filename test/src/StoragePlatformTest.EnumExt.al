namespace Origo.Bifrost.Attachments.Test;

using System.ExternalFileStorage;

/// <summary>Registers an arbitrary test connector through the same platform interface as third-party apps.</summary>
enumextension 96236 "Storage Platform Test ori" extends "Ext. File Storage Connector"
{
    /// <summary>Account-isolated in-memory platform connector with no provider metadata schema.</summary>
    value(96236; "Interface Test ori")
    {
        Caption = 'Interface Test', Locked = true;
        Implementation = "External File Storage Connector" = "Storage Platform Fake ori";
    }
}
