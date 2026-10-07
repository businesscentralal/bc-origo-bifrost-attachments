namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Foundation.Attachment;

/// <summary>Native target prerequisites without Customer source read. Union with Target adds the positive native baseline.</summary>
permissionset 96220 "Storage79 Source ori"
{
    Assignable = true;
    Access = Internal;

    Permissions =
        tabledata "Document Attachment" = RIMD;
}
