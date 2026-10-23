# Issue 168 owned-container file fixture

The test extension's `MCP Loopback 168` connector (96266) uses an HTTP listener on
`localhost:9626` in the developer's individually owned BC container. The product
extension does not contain this connector. It verifies message response contracts
against real external file persistence without database writes inside a
TryFunction. It is not production-provider, atomic-move, SaaS or licensing proof.

Run `fixtures/Start-StorageHttpFixture.ps1` inside the owned container, retaining
its process ID. Enable outbound HTTP only for the test extension, as required to
reach this fixture; do not change Foundation/product HTTP, consent, licence or
TryFunction settings. Create a Storage Setup through its normal Web Client page,
with a unique `W8168`-prefixed code, `MCP Loopback 168` type, enabled, and empty
base path. File names must begin `w8168` and contain only ASCII letters, digits,
dots, underscores and hyphens. The loopback listener accepts no other namespace,
serves no directories, and limits uploads to 10 MiB.

Self-seed files through Storage.File.Create, then exercise Copy/Get/Exists and
Delete in both caller languages. Assert response fields and bytes. Use separate
paths for each run. Record exact deployed artifact/source hashes and actual
results. The native fixture isolation tests (96267) require no listener or HTTP
permission.

Delete all owned files through the API, verify absence, delete the owned setup,
stop the recorded listener process, remove its owned data directory, and read
back process/filesystem state. Disable the test extension's HTTP permission when
retaining the container. Delete and verify the individually owned container when
its work ends. Never touch another worker's data or environment.
