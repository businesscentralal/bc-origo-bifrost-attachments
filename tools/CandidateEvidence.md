# Candidate evidence inventory (#80)

```sh
python3 tools/collect_candidate_evidence.py /owned/evidence/packet.json > inventory.json
python3 -m unittest discover -s tools/tests -p test_candidate_evidence.py -v
```

The collector reads local files. Exit 0 means the requested inventory is structurally
complete; 2 means explicit evidence gaps; 1 means malformed, missing, changed or
inconsistent input. All results keep `candidateCertified`, `runnerCertified` and
`releaseReady` false. Actual owner-supported raw-output review is still required.
No network, package publication, provisioning, signing or credential access occurs.
Use sanitized evidence in a dedicated directory. Never put credentials in a packet.

## Packet format

```json
{
  "schema": 1,
  "sourceCommit": "cefe72faddc19a5f02c4b0d071a5d266b52705cf",
  "markets": ["IS","GB","DK","NO","SE","FI","DE","FR","NL","AT","CH","IE","PT","ES"],
  "providers": ["AzureBlob","AzureFileShare","SharePoint"],
  "candidate": null,
  "receipts": []
}
```

This example is intentionally blocked. The commit is an observation, not an approved
candidate. Use the full integrated source commit when it is established. A candidate
object requires `appId`, `publisher`, `version`, `sha256`, `contentSha256`,
`sourceCommit`, `buildUrl`, `friends: []` and `foundation`. The current Foundation
object requires `appId`, `version: "28.0.3.530"`, `sha256` and `friends: []`.
These are expected identities, never a claim of inspected/signed package bytes.
The #78 owner must provide the genuine package and provenance. Renaming a 523
fixture is invalid. Foundation 530 selection is specific to this current candidate;
it does not change the product's dependency floor.

Each receipt reference is `{ "path": "receipt.json", "sha256": "<64 lowercase hex>" }`.
Paths resolve inside the packet directory, including through symlinks. Every file is
bounded to 16 MiB, the receipt list to 512 and raw outputs per receipt to 64. Duplicate
JSON keys, rows, reused receipt paths and mismatched digests fail. JSON errors are
reported without echoing parser input or local OS error text.

Each normalized receipt has `row`, `owner`, `observedAt`, `sourceCommit`,
`candidateSha256`, the exact candidate `foundation` object, `evidenceKind`
(`actual`, `fixture`, `diagnostic`), `outcome` (`passed`, `failed`, `blocked`) and a
nonempty `rawOutputs` array of local hash references. Normalization must preserve
original native #78 state/finalize/postSign receipts and logs as raw outputs; it
must not replace or rewrite them. This version checks their byte custody and
normalized identity, not their native schema or signature trust.

Required summary rows are:

- `Default.postcompile`, `Default.postSign`, `Test.postcompile`, `Test.runtime`
- `source.guards`, `tools.guards`, `pipeline.identity`, `cleanup`
- `restricted.runtime`, `lifecycle.runtime`, `MCP.runtime`, `UI.runtime`
- `market.<country>` for all 14 countries in the existing AppSourceCop file
- `provider.AzureBlob`, `provider.AzureFileShare`, `provider.SharePoint`

Runtime rows include integer `counts` with `discovered`, `selected`, `executed`,
`passed`, `failed`, `skipped`, `aborted`, `notRun`. All discovered tests must be
selected; executed equals passed + failed + aborted; selected equals executed +
skipped + notRun. Zero passes or any failed/skipped/aborted/not-run tests retain a gap.

## Acceptance boundary

| Evidence | Required owner review beyond collection |
| --- | --- |
| Default/Test | Exact runner SHA (including merge parents), app/test 0 errors and 0 warnings, actual compiler/analyzer/ruleset/symbol hashes and catalog provenance |
| Default signing | Unchanged candidate bytes, trusted signature chain/timestamp, publisher/AppId, no friends, pipeline postSign and package content identity |
| Test lane | Same-source compile inputs and exact production test-compile app republished before tests; never substitute Test bytes for signed Default |
| Pipeline | Sequential shared disposable physical container, signing requests, final cleanup, unchanged UAT/settings/variables, Test-only last-release-upgrade skip |
| Markets/providers | Exact full BC release/country/dependencies, all approved per-case assertions, readbacks and cleanup |
| Restricted/lifecycle | Genuine principals, provider grants, approved legacy/baselines, actual lifecycle operations and installed versions |
| Source/tool guards | Raw logs at the exact source, all required guards, accepted source integration and build-generated translations |

These 29 summary rows do **not** replace the existing 36 provider cases, 10 lifecycle
rows or market/release matrix. Their detailed owner outputs and accepted scenario
plans remain mandatory. The collector cannot establish completeness of those
nested scenarios. Fixtures prove collector behavior only; diagnostic compilation
is not current runner/runtime evidence. Absent offer ID is a publication/material
gap and does not block this safe local tooling work. No publication is implemented.
