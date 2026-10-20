namespace Origo.Bifrost.Attachments.Test;

/// <summary>Permissions for test-only persisted storage fixtures; never part of the production app.</summary>
permissionset 96261 "Storage MCP Test ori"
{
    Assignable = true;
    Permissions = table "Storage MCP File ori" = X,
                  tabledata "Storage MCP File ori" = RIMD,
                  codeunit "Storage MCP Connector ori" = X,
                  table "Storage MCP Cleanup Item ori" = X,
                  tabledata "Storage MCP Cleanup Item ori" = RIMD,
                  codeunit "Storage MCP Cleanup ori" = X;
}
