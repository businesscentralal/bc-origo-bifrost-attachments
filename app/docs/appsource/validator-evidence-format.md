---
title: Check the Attachments validator evidence
audience: validator
keywords: Attachments, sandbox, evidence, cleanup
locale: en-US
---

# Check the Attachments validator evidence

Run the executable, secret-free preparation check from the repository root:

```sh
python3 tools/validate_submission.py
```

It checks the committed source inventory, source-declared market CSV, twelve
scenario families, local submission links and unconfigured offer delivery. Exit
0 means those preparation checks are consistent; it does **not** mean QA,
certificate trust, a sandbox smoke run or release acceptance passed. Exit 1 means
malformed/unavailable input; exit 2 identifies acceptance gaps. No network,
installation, consent, signing, fixture mutation or publication occurs.

## Validate a later actual smoke run

After passing exact-candidate #80 QA, execute the independent steps in
[validator-smoke-script.md](validator-smoke-script.md) on a validator-owned sandbox.
Record actual observations and sanitized evidence links. Then run:

```sh
python3 tools/validate_submission.py --smoke-receipt /owned/evidence/smoke.json --package /owned/evidence/Attachments.Default.app
```

The checker reads the actual NAVX package, compares its source/version/hash and
friend grants with the receipt, requires matching QA and real-certificate
trust/tamper references, checks every smoke step, compares the retrieved synthetic
file bytes, and reconciles owned fixture creation/removal/absence lists. It rejects
missing, failed, skipped, duplicate and unknown steps. It cannot authenticate an
external observation, establish an installed runtime hash or execute the UI/API
flow: the retained QA/certificate owners and independent reviewers inspect the
linked raw evidence. A consistent receipt is not certification. Run separately
for LCIDs1033/1039; it does not claim fourteen-market or full-provider coverage.

Use this JSON shape, replacing placeholders only with actual evidence. **This
example is incomplete and must fail validation.** Do not turn an unexecuted row
into a pass to satisfy the checker. Keep credentials, tokens, provider account
secrets and customer data out of the receipt. Evidence URLs must be HTTPS, with
no embedded user/password or query token. Sensitive raw evidence stays in its
approved private evidence location; use a sanitized receipt URL here.

```json
{
  "schema": 1,
  "sourceCommit": "FULL_ACTUALLY_TESTED_SOURCE_SHA",
  "candidate": {"sha256": "ACTUAL_SIGNED_DEFAULT_SHA256", "version": "ACTUAL_PACKAGED_VERSION"},
  "environment": {
    "id": "OWNED_SANDBOX_ID", "owner": "ACTUAL_VALIDATOR", "company": "SELF_CREATED_COMPANY",
    "bcVersion": "ACTUAL_VERSION", "country": "ACTUAL_COUNTRY", "lcid": 1033,
    "sandbox": true, "validatorOwned": true
  },
  "qa": {
    "outcome": "unrun", "sourceCommit": "FULL_ACTUALLY_TESTED_SOURCE_SHA",
    "candidateSha256": "ACTUAL_SIGNED_DEFAULT_SHA256", "evidenceUrl": "",
    "foundation": {"version": "QA_INSTALLED_VERSION", "sha256": "QA_INSTALLED_PACKAGE_SHA256"}
  },
  "foundation": {"version": "ACTUAL_INSTALLED_VERSION", "sha256": "ACTUAL_INSTALLED_PACKAGE_SHA256"},
  "signature": {
    "status": "UNVERIFIED", "realCertificate": false, "tamperRejected": false,
    "candidateSha256": "ACTUAL_SIGNED_DEFAULT_SHA256", "evidenceUrl": ""
  },
  "createsOwnData": true,
  "nonSuperIdentity": true,
  "steps": [],
  "readbackContentBase64": "",
  "negative": {"status": "UNVERIFIED", "code": "", "parameter": "", "nextStep": "", "stateUnchanged": false},
  "cleanup": {"created": [], "removed": [], "verifiedAbsent": [], "evidenceUrl": "", "containerRetained": true}
}
```

`steps` contains exactly one row per identifier below, each with `id`, actual
`outcome` and `evidenceUrl`. A successful checker requires all to be `passed`:

| Identifier | Actual observation required |
|---|---|
| `setup` | Open the setup page in the recorded language with the exact installed app/dependencies |
| `connection` | Create the isolated connection and observe its real Test Connection result |
| `account-list` | Public `Storage.Account.List` returns the owned connection |
| `help-create` | Retrieve current `Storage.File.Create` contract |
| `help-get` | Retrieve current `Storage.File.Get` contract |
| `create-file` | Create `as81.txt` containing exactly `Attachments validator sample` in the owned run folder |
| `get-file` | Read back and compare every byte; record actual `contentBase64` as `readbackContentBase64` |
| `missing-storage` | Record the structured missing-storage-code refusal and unchanged DB/provider state |
| `cleanup` | Remove every owned fixture and independently verify absence |

`cleanup.created`, `removed` and `verifiedAbsent` contain the same nonempty unique
set of actual run-owned resource identifiers (connection, file, folder, account
and any upload session). Never list a foreign fixture. Retain the development
container for amendments until Tester postdeploy UAT and issue closure; container
retention is separate from test-data cleanup. Record later authorized deletion
and404 readback separately. No offer operation is part of this tool or smoke run.
