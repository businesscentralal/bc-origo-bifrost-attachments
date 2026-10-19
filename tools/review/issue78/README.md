> **Applied 19.10.2026** to `.github/workflows/_BuildALGoProject.yaml` on Gunnar's approval (owner decision, AppSource preparation).
> `verify_proposal.py` accepted the applied workflow and rejected 15 mutations; `Test-BifrostPipeline.ps1` passes.
> The Windows NAVX signed/tampered check remains a manual step under #78.

# Issue 78: final workflow gates, pending infrastructure-owner review

This is a concrete **unapplied** workflow change. No `.github` file is modified.
The issue's implementation contract says: “do not commit .github changes or
silently bypass the existing infrastructure review requirement.” The explicit
next owner is **ori-haraldurb**, with Architect/internal-review coordinating
technical disposition. This packet cannot grant that approval.

`pipeline-final-gates.patch` is prepared against main
`c92048a69e797866cbda480c54d466d4d6d4e58c`. It adds the existing gate entry point
immediately after RunPipeline and Sign, supplies the actual build mode, and gates
Apps/TestApps uploads on successful final receipts. Default shipping requests run
Signed even if the Sign action was unexpectedly skipped; disabled signing settings
cannot silently yield an accepted unsigned shipping artifact. Test mode and
unsigned PR builds use Pipeline without claiming signature trust. Existing signing
conditions, action pins, credentials, settings, container identity and cleanup are
preserved. Final receipt uploads allow only the three sanitized stage receipts.

The current runner must support Windows NAVX SIP/trust. The existing Signed gate
requires a real `Valid` Authenticode result and signer certificate. Missing SIP,
unknown trust, an absent package or an invalid signature fails. This packet does
not install a SIP, change trust stores, grant infrastructure permission, or claim
an actual signature verdict. An approved Windows test must verify the exact signed
Default package and refusal after tampering before acceptance.

Review validation (source only):

```powershell
git apply --check tools/review/issue78/pipeline-final-gates.patch
# In a disposable review checkout, after recording infrastructure approval:
git apply tools/review/issue78/pipeline-final-gates.patch
python tools/review/issue78/verify_proposal.py <original-workflow.yaml> .github/workflows/_BuildALGoProject.yaml
./tools/Test-BifrostPipeline.ps1
./tools/Test-SharedAlpacaContainer.ps1
```

The review utility requires PyYAML 6. It checks immediate gate ordering, mode,
conditions, no failure suppression, preserved producer/secret/settings/cleanup
steps, upload enforcement and the receipt allowlist. It rejects 15 mutated
proposals. These checks establish proposal structure, not Actions expression
execution, compiler output, BC tests, Windows trust or current-run acceptance.

Remaining delivery: obtain recorded infrastructure-owner approval, apply the patch
through that owner, register and verify exact-tip Default/Test CI and immutable
packages/receipts, execute genuine Windows signed/tampered NAVX checks, and retain
review, provider/UAT and cleanup evidence. Keep #78 open until all four ACs have
current-candidate evidence. No merge, deployment or publication is authorized by
this packet.
