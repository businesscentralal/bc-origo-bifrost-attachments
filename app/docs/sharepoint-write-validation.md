# SharePoint write validation (#120)

Microsoft connector dependencies have a minimum version of **28.0.0.0**, matching
the application's Business Central 28 floor. Attachments does not pin an exact
connector build. Schema validation remains in place; partner connectors retain
their existing generic path.

SharePoint account identity uses only public table 4580 fields: `Id` (1),
`SharePoint Url` (4), and `Base Relative Folder Path` (5). No secret field or
credential getter is read. Account-table read through `BIFROST Attach ori` is
indirect, raised only inside `Storage Ext File Impl ori`.

The path composition mirrors Microsoft's BC28 connector `InitPath`: combine
the account folder with the setup-prefixed request path, ensure a leading slash,
then prepend the site's URI absolute path unless already present. Identity uses
the decoded server-relative path and lower-case authority, so separate account
rows, encoded spaces and case aliases cannot evade attachment protection.
The full decoded path, including site and library, must fit 400 characters.
Malformed/traversal paths, residual percent escapes, query/fragment characters
and non-ASCII comparison identities remain a structured preflight refusal until
their exact provider comparison behavior is verified. Ordinary ASCII SharePoint
paths, including spaces and encoded spaces, no longer encounter the unconditional
SharePoint refusal.

Source provenance: [Microsoft BCApps BC28 connector, immutable commit
b8e89d71bec21223d04fa7844e962b5989831ee6](https://github.com/microsoft/BCApps/tree/b8e89d71bec21223d04fa7844e962b5989831ee6/src/Apps/W1/External%20File%20Storage%20-%20SharePoint%20Connector/App/src).
This source verification does not substitute for testing installed connector
versions and actual provider behavior.

Acceptance requires the full write matrix on owned disposable BC28 W1 and IS
environments, actual Blob/File Share/SharePoint fixtures, attachment alias and
move readback, restricted identities, applicable language checks, exact-candidate
CI and cleanup evidence. Source regressions and mock tests alone do not establish
this provider acceptance.
