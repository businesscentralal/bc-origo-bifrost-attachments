# Incoming-document MCP fixture (#23)

The test extension adds the `MCP Fixture 23` storage type (96250), backed by the
`Storage 23 Fixture File ori` test table. Unlike the existing session-local Mock,
these bytes remain available between separate MCP calls. Configure a unique owned
`Storage Setup ori` code with this type in an individually owned development
container, then seed each owned file through the public `Data.Records.Set` message
on test table `Storage 23 Fixture File ori`: primary key `StorageCode` and `Path`,
with base64 bytes in `Content`. Use the JSON field keys from `Help.Fields.Get`.
This database-writing message persists the fixture before `CreateLinked` reads it.
External-only `Storage.File.Create` and `Storage.File.Delete` run inside a
TryFunction on on-premises containers and cannot perform this fixture's database
insert/delete. Do not change the server's TryFunction setting for this fixture.

Use it to exercise the normal production dispatcher, validation, upload, linked
attachment read and base-app Data Exchange processing paths in LCIDs 1033/1039.
It neither accepts EULA/trial/licence state nor intercepts licensing. It is a test
connector, not evidence of Azure Blob/File Share/SharePoint provider behavior.
Files are isolated by storage code and path. Only file create/read/delete/exists
and list are implemented; unsupported operations fail explicitly.

If retaining the environment, remove only scenario-owned documents through the
normal Business Central pages. At task completion, delete the individually owned
container and verify its 404 response. This removes the fixture table, upload
sessions, definitions, vendors and unposted invoices together, with no external
storage left behind. Do not run external-only file deletion against this
SQL-backed fixture or change the server's TryFunction setting. Never configure
this fixture on a shared or customer environment.
