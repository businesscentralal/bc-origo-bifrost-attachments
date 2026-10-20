---
title: Prepare Attachments market evidence
audience: release-owner
keywords: AppSource, Attachments, markets, dependencies
locale: en-US
---

# Prepare Attachments market evidence

Current technical receipt: [build113 evidence](candidate-2026-10-20.json), source `c30c2254bf953ed2e6f90fdf080dfb216bea799f`, existing CI **365/365/0/0**. This is preparation evidence; final #80 QA and certification remain pending. [Run the executable preparation/receipt checker](validator-evidence-format.md).

**Fourteen source-declared countries, zero countries certified by this document.** Codes match `app/AppSourceCop.json` and [partner-center-markets.csv](partner-center-markets.csv). Locales1033/1039 are language checks, not a substitute for market coverage. W1 or one provider run cannot certify the other countries.

The inspected source is main `c30c2254bf953ed2e6f90fdf080dfb216bea799f` (CI39298155811, package28.0.0.113, one dependency: Bifrost Foundation28.0.3.530). Its signed artifact hash is recorded in the linked build113 receipt. Installed Foundation runtime identity/hash, real-certificate trust and the connector apps installed per country remain pending current-candidate #78/#80 evidence and Architect’s release-candidate confirmation. Build87 is excluded by decision1792179827. Do not populate this matrix with historical or foreign fixture passes.

| Code | Country | Candidate/build/dependency evidence | Provider/lifecycle/UI/MCP result | Owner / status |
|---|---|---|---|---|
| IS | Iceland | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| GB | United Kingdom | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| DK | Denmark | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| NO | Norway | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| SE | Sweden | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| FI | Finland | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| DE | Germany | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| FR | France | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| NL | Netherlands | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| AT | Austria | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| CH | Switzerland | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| IE | Ireland | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| PT | Portugal | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |
| ES | Spain | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 / worker-8; operator availability input pending |

## Complete every country row after candidate selection

1. Record country/localization, BC release/full build and exact signed candidate source/version/hash. Attach the actual run/artifact receipts, not a list of declared countries.
2. Record every final dependency's AppId, publisher, name, minimum and installed version, package hash and resolution/availability evidence in that country. The package declares no connector dependency (PR118, PR144), so record the Microsoft connector apps actually installed in that country and confirm BC 28.3 or later (the application floor). #78 reconciles actual Foundation runtime hash/trust.
3. Link the applicable #80 provider cases, lifecycle cases and UI/MCP1033/1039 observations by case ID, exact SHA, self-created fixture owner and real executed/passed/failed/skipped counts. Explain any country-specific applicability; never infer all-provider coverage from a mock or from one provider's connector.
4. Record supported activation and genuine non-SUPER setup/usage/denied-identity prerequisites from #79. Dedicated Blob/File Share/SharePoint allocations and restricted identities remain external owner inputs routed by Architect; no licence/backend writes.
5. Attach developer/validator fixture cleanup evidence. Record retained development container name/id and its final deletion trigger (Tester postdeploy UAT pass and issue closure); UAT data needs no cleanup.
6. Gunnar/designated offer owner supplies separately authorized listing/market comparison evidence. A source code, BC localization success and Marketplace dependency availability are distinct facts. Offer creation/submission/publication is outside #81 authority.

## Handoff record for each row

Use these fields in the sanitized #80 acceptance receipt: `country`, `bcBuild`, `sourceSha`, `appVersion`, `appSha256`, `dependencies[{appId,publisher,name,minVersion,installedVersion,sha256,resolutionEvidence}]`, `caseIds`, `languages`, `executed`, `passed`, `failed`, `skipped`, `fixtureOwner`, `fixtureSetupEvidence`, `cleanupEvidence`, `developmentContainer{name,id,retentionTrigger}`, `operatorAvailabilityEvidence`, `blockerOwner`, `nextAction` and `evidenceUrls`. Unavailable inputs stay named blockers; empty or unexecuted rows never become passes.

This preparation does not change the market list, dependency floor, provider scope or source custody. Formal scenario generation and validator dry-run wait for #80 passing QA on the accepted integrated candidate.
