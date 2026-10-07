namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Foundation.Attachment;
using Microsoft.Sales.Customer;

/// <summary>Customer source read and attachment read without target mutation. No product-role grants.</summary>
permissionset 96221 "Storage79 Target ori"
{
    Assignable = true;
    Access = Internal;

    Permissions =
        tabledata Customer = R,
        tabledata "Document Attachment" = R;
}
