---
title: Prepare Attachments market evidence
audience: release-owner
keywords: AppSource, Attachments, markets, dependencies
locale: en-US
---

# Prepare Attachments market evidence

Inspected source: [`b7310c3308e5cb216b6aa5ff0db2ca5645607d6b`](https://github.com/businesscentralal/bc-origo-bifrost-attachments/commit/b7310c3308e5cb216b6aa5ff0db2ca5645607d6b). See the [8 November preparation reconciliation](preparation-2026-11-08.md) for current manifest, offer configuration and acceptance gaps. No final QA candidate is certified. [Build113](candidate-2026-10-20.json) remains historical evidence for its own bytes only.

**Fourteen source-declared countries, zero countries certified by this document.** Codes match `app/AppSourceCop.json` and [partner-center-markets.csv](partner-center-markets.csv). Locales1033/1039 are language checks, not a substitute for market coverage. W1 or one provider run cannot certify the other countries.

The inspected source is `b7310c3308e5cb216b6aa5ff0db2ca5645607d6b`, version 28.3.2.0, with product Foundation minimum 28.0.11.669. It is not a nominated or certified release candidate. Historical build113 signature and test results remain in their immutable receipt. The [partial country compile matrix](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/80#issuecomment-6619184813) used a different unsigned source/dependency and supplies no current-candidate market pass. #80's [4 November verify-close check](https://github.com/businesscentralal/bc-origo-bifrost-attachments/issues/80#issuecomment-6626908886) leaves final QA incomplete.

| Code | Country | Candidate/build/dependency evidence | Provider/lifecycle/UI/MCP result | Owner / status |
|---|---|---|---|---|
| IS | Iceland | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| GB | United Kingdom | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| DK | Denmark | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| NO | Norway | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| SE | Sweden | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| FI | Finland | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| DE | Germany | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| FR | France | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| NL | Netherlands | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| AT | Austria | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| CH | Switzerland | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| IE | Ireland | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| PT | Portugal | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |
| ES | Spain | Pending accepted SHA and country-specific build/resolution receipt | Not executed; no pass claimed | #80 retained QA owner; operator availability input pending |

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
