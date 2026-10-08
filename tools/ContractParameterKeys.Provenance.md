# Contract guard source provenance

`Test-ContractParameterKeys.ps1 -SelfTest` runs the original guard tests, the
unchanged call-context assertions, and the output/source-provenance tests.
These fixtures test source analysis, not AL compilation or runtime behavior.

The guard follows literal `Codeunit.Run(Codeunit::"Name", Argument)` into a
source-backed codeunit's `OnRun` only when its `TableNo` and the record argument
both identify `Message Argument ori`. Unavailable, incompatible, dynamic and
ambiguous paths fail; dispatch references alone are not reads.

Request JSON returned through a `var JsonObject` can acquire provenance from a
single unconditional `Argument.GetRequestJson()` assignment, direct forwarding,
or a bounded Boolean success wrapper. A TryFunction result or success wrapper
only establishes provenance inside the exact positive `if Call(...) then`
branch. An unchecked result, compound condition, alternative successful exit,
loop, alias, extra assignment or unknown mutation cannot establish that proof.
Output proof recursion is capped at depth 16 and 256 calls per candidate. The
existing read traversal caps (depth 40, 2000 contexts) remain enforced.

Every forwarding hop retains its own TryFunction success requirement. A checked
outer call cannot compensate for an unchecked fallible inner forwarding call.
Caller assignments whose right side references a proven output end that output's
proof range and report unsupported analysis. This deliberately rejects aliases,
including read-only aliases and aliases later reassigned: no reference tracking
is claimed. Direct reads and source-proven read-only calls remain supported.

A JSON argument passed by value still refers to a mutable object. Preserving
request provenance through forwarding therefore requires source-proven reads
through the complete bounded call chain. Mutation, aliases, unknown calls,
by-reference forwarding and exhausted proof budgets fail conservatively.

## External dependency reader

No source is downloaded, inferred from a package filename, or loaded by default.
A caller may supply **one source file** through:

```powershell
./tools/Test-ContractParameterKeys.ps1 `
    -AppFolder ./app `
    -DependencySourceManifest /protected/evidence/reader.json `
    -DependencySourceManifestSha256 <independently-approved-manifest-sha256>
```

The manifest must be captured and reviewed from the exact immutable source
revision. The hash argument is the trust anchor: retain it independently of the
manifest, rather than calculating it from arbitrary input at execution time.
The guard verifies that approved manifest's bytes, not the authority of its
supplier. It performs no network lookup to re-attest repository tree membership.
The approved capture must establish that association.

Schema 1 (example values, not usable production evidence):

```json
{
  "schemaVersion": 1,
  "repo": "Owner/Repository",
  "sourceSha": "<40 lowercase hex commit>",
  "repositoryPath": "app/src/Argument.al",
  "blob": "<40 lowercase hex Git blob>",
  "sha256": "<64 lowercase hex source hash>",
  "sharedPath": "/protected/evidence/Argument.al",
  "namespace": "Example.Dependency",
  "objectKind": "table",
  "objectId": 123,
  "objectName": "Message Argument ori",
  "dependency": {
    "id": "<dependency app ID>",
    "name": "<dependency name>",
    "publisher": "<dependency publisher>",
    "version": "<version declared in the consumer app.json>"
  }
}
```

Manifest size is bounded to 64 KiB; source size to 2 MiB. The guard checks the
manifest hash, immutable identifiers, source SHA256, Git blob hash, namespace,
object kind/ID/name, and exact consumer dependency declaration. It rejects
collisions with local objects and multiple objects. Parsing uses the verified
source bytes, without rereading them after verification. No private dependency
source belongs in the product repository.

A missing manifest leaves missing-dependency findings intact. A malformed or
mismatched manifest is a failing invocation, never an allow-list entry. Even a
successful source-pinned invocation proves only which source keys are read. It
does **not** prove compiled-package byte equality, runner/signature trust,
Foundation version acceptance, product runtime, or PR readiness.
