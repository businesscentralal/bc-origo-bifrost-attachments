# Incoming-document MCP fixture (#23)

The test extension adds the `MCP Fixture 23` storage type (96250), backed by the
`Storage 23 Fixture File ori` test table. Unlike the existing session-local Mock,
these bytes remain available between separate MCP calls. Configure a unique owned
`Storage Setup ori` code with this type in an individually owned development
container, then create every file with `Storage.File.Create` or chunked upload.

Use it to exercise the normal production dispatcher, validation, upload, linked
attachment read and base-app Data Exchange processing paths in LCIDs 1033/1039.
It neither accepts EULA/trial/licence state nor intercepts licensing. It is a test
connector, not evidence of Azure Blob/File Share/SharePoint provider behavior.
Files are isolated by storage code and path. Only file create/read/delete/exists
and list are implemented; unsupported operations fail explicitly.

Delete only the incoming documents and other records created for the scenario,
then delete their fixture files and setup. Verify zero matching rows and retain
exact deployed app/source provenance. Container deletion and a verified 404 close
any remaining owned test state. Never configure this fixture on a shared or
customer environment.
