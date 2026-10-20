---
title: Run the gated Attachments validator sandbox smoke script
audience: validator
keywords: Attachments, sandbox, smoke, cleanup
locale: en-US
---

# Run the gated Attachments validator sandbox smoke script

**Manual test script; not executed.** Run only after the exact candidate passes internal QA on the Architect-defined integrated SHA, with formal scenarios derived from that evidence. This script contains no executable network or publication command. Stop at the first failed prerequisite; do not interpret a stopped run as a pass.

The [executable preparation and receipt checker](validator-evidence-format.md)
validates inputs/evidence locally. It does not execute these sandbox steps or
replace passing #80 QA. Record real observations before using its optional smoke
receipt mode; a stopped/unrun flow is never a pass.

## Validate inputs before running

| Input | Required proof / reject condition |
|---|---|
| Environment | Validator owns the disposable sandbox; recorded sandbox ID, BC version/country and test company. Reject production, personal/shared/operator environments or unknown ownership |
| Candidate | Full source SHA, signed package SHA256, installed Attachments version, Foundation version/hash exactly match the passing #80 evidence. Use the accepted Foundation version/hash, the connector apps actually installed, installed-runtime identity and Windows trust receipt from #78/#80; historical523/build87 do not satisfy this prerequisite. Keep the source minimum 28.0.3.530 distinct from the installed and tested Foundation version. Reject missing/mismatched values |
| Access | Secure public Foundation API transport, activated test license, #79-proven non-SUPER role grants and dedicated provider File Account. Reject missing rights, customer data or embedded credentials |
| Fixture | Connection `AS81` and unique run folder reserved for this run; synthetic text bytes only. Reject an existing unowned connection/folder or an uncertain cleanup boundary |
| Cleanup | Validator can abort own upload, remove own files/connection/account and retain the recorded development container until the required postdeploy UAT/issue-closure gates, with an authorized owner able to delete it afterward. Reject missing cleanup/retention ownership |

The actual offer ID is not an input to this smoke test. It must not create or submit an offer.

## Execute and record observations

1. Record UTC start, owner, sandbox/company, language and candidate/dependency/package identities in a private sanitized run record.
2. Open the Attachments module through Foundation's registered Apps entry. Confirm the page caption `Bifrost Attachments Setup`.
3. Choose `Bifrost Storage Setup`. Create the reserved connection with its registered File Account, production External File Storage backend, dedicated Base Path and Enabled state.
4. Open the connection card, whose caption is `Bifrost Storage Connection`. Choose `Test Connection`. Record the exact observed result; compare it with the formal candidate-specific expectation.
5. Use the approved Foundation public transport to call `Storage.Account.List`. Confirm the reserved connection appears.
6. Retrieve `Help.Implementation.Get` for `Storage.File.Create` and `Storage.File.Get`; use the exact envelope and parameters from the formal tested scenarios.
7. Create `as81.txt` under the reserved run folder with content `Attachments validator sample`.
8. Retrieve it with `Storage.File.Get`. Decode returned `contentBase64` and compare every byte with the input. A success status alone is insufficient.
9. Run the formal missing-storage-code negative request. Compare the status/error code/parameter/next step to its recorded candidate expectation. Confirm the synthetic file is unchanged.
10. Record each executed step as pass/fail with its response or observable evidence. Report unexecuted steps separately. This smoke result does not cover uploads, offload, Data Exchange, all providers/markets or lifecycle certification.

## Clean up even after failure

1. Abort any open upload sessions created by this run, if applicable; record each identifier and result.
2. Delete only the synthetic file and owned empty run folder. Confirm absence through the supported storage read/existence operations; account for any failure explicitly.
3. Remove only this run's connection, provider File Account and connector fixture. Revoke temporary provider access through the approved owner; never log secret values.
4. Record the development container name/id and retain that same resource for amendments. Delete it only after Bifröst Tester passes post-deployment UAT and the issue closes, then verify deletion with404 readback. Do not delete at merge, PR close or smoke completion. UAT has no test-data cleanup requirement.
5. Record UTC stop, actual step counts/outcome and cleanup proof. If cleanup fails, record the resource ID, named owner and next action; the run remains blocked.

Working-material preparation is approved at `app/docs/appsource`; execution follows passing #80 QA on the integrated candidate. No smoke execution or environment result is claimed by this script. The dated6October no-offer decision is preserved; this is not a fresh offer lookup and no offer operation is part of this script.
