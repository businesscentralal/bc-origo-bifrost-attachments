---
title: Collect Attachments release evidence
audience: release-owner
keywords: AppSource, Attachments, Partner Center, release gates
locale: en-US
---

# Collect Attachments release evidence

**Source baseline:** Attachments `b42ad90eaee2803205408a1cac8b0d9752b91c0e`; Foundation comparison `0fb78c0be538bd77c482c70eddbbef451f697cc9`; standards `52ba4754cfd614e4a7c50af87b30149b18b313e3`. Source inspection is not signed-artifact or runtime proof. No release candidate has been certified by this package.

## Confirm identity and markets

| Item | Source evidence | Release gate / accountable owner |
|---|---|---|
| App | `Bifrost Attachments`, publisher `Origo`, AppId `672df32a-a0c5-4a22-b591-0efa38023e95` | #80 / worker-8: match signed manifest and listing |
| Version | Source `28.0.0.4` | #80 / worker-8: record actual packaged/deployed version; do not infer it from source |
| BC floor | Application/platform `28.0.0.0`, runtime `17.0`, Cloud | #80 / worker-8: prove supported releases with unchanged floor |
| Foundation | AppId `7505e808-6e52-4b96-a328-82573391297a`, Origo, minimum `28.0.1.0` | #74/#80 / worker-8: immutable dependency version/hash, availability per market; latest-build probing is not an immutable input |
| Countries | IS, GB, DK, NO, SE, FI, DE, FR, NL, AT, CH, IE, PT, ES | `app/AppSourceCop.json`; [CSV](partner-center-markets.csv). #80 / worker-8: fourteen-market evidence and Partner Center comparison |
| Locales | `en-US`, `is-IS` | #71/#72: translations and runtime language proof; locales are not the market list |
| Registered suffix/ranges | Source `ori`; `10035635–10035684` and `70013500–70013549` | Gunnar / offer owner: registration evidence for publisher suffix and both ranges. Source declarations alone do not prove registration |
| New Attachments offer | Gunnar confirmed on 2026-10-06: no Partner Center offer exists; no existing product ID is available | Gunnar / offer owner: future offer creation requires separate authorization; this assignment prepares the material only |
| Genuine offer/product ID | Unavailable until the new Attachments offer is created; `deliverToAppSource` remains unconfigured | Gunnar / offer owner: supply the genuine new offer ID after authorized creation; internal-review must confirm its Attachments mapping before any separately approved configuration change. Never copy Foundation's ID or invent a dummy |

## Collect listing, asset and external-service evidence

| Item | Current evidence | Required next action / owner |
|---|---|---|
| Listing text | `app/app.json` brief/description names Azure Blob, Azure File Share, SharePoint, uploads and offloading | Offer owner: approve Attachments-specific name, summary, description, categories and supported languages; match only proven shipping features |
| Logo | `app/assets/Logo250x250.png` exists in the source | Offer owner: approve rights, branding and current Partner Center dimensions/variants; source existence is not listing approval |
| Screenshots | Manifest `screenshots: []` | #80 / worker-8 supplies candidate screenshots; offer owner approves English/Icelandic captions, rights and listing assets. Use synthetic data and remove identifiers |
| Product/help | `https://businesscentralal.github.io/bifrost/en-us/attachments/`; context help uses `{0}/help/attachments/` | #70 / documentation owners: confirm exact shipped page help routes, redirects and accessibility; internal-review coordinates externally published changes |
| Legal | EULA `https://businesscentralal.github.io/bifrost/en-us/foundation/eula/`; privacy `https://businesscentralal.github.io/bifrost/en-us/foundation/privacy/` | Gunnar / legal owner: confirm these shared policies explicitly cover Attachments and external file handling. A manifest URL is not legal acceptance |
| Support | Publisher website `https://www.origo.is/`; no separate support contact evidenced here | Gunnar / offer owner: approved support URL/contact, response process and customer-facing dependency guidance |
| Provider prerequisites | BC External File Storage connector apps and registered File Accounts; Attachments stores account references | Gunnar / provider owner: validator-accessible dedicated Azure Blob, Azure File Share and SharePoint fixtures, constrained rights, quotas and availability window. Provide secrets separately using an approved secure channel |
| Foundation activation/API | Foundation's setup, licensing and public message transport are required | #79/#80: actual non-SUPER role names, license/activation steps and secure authenticated transport instructions from the tested candidate |

The test app's in-memory Mock connector is internal automated-test infrastructure. Do not advertise it as a production demo mode or substitute it for advertised provider validation. Never put passwords, tokens, customer documents or connection strings in these files, screenshots, evidence or issue comments.

## Close technical and human gates

- [ ] #74 compilation repair integrated through authorized merges; exact app/test build reports show 0 errors and 0 warnings.
- [ ] #78 compiled-package/compiler gates and infrastructure integration reviewed by ori-haraldurb; no workflow patch is applied by this documentation task.
- [ ] #69/#82 contracts and refusals match shipped behavior; #75 linked-file safety and #76 lifecycle takeover are proven; #77 public surface audit completed.
- [ ] #70 help and #71/#72 translations complete; #79 setup/usage and denied-user tests run with genuine non-SUPER identities.
- [ ] #80 internal QA passed on one immutable signed candidate, with package/dependency/compiler identity, unit pass count, all local `Test-*.ps1` results, MCP/UI and fourteen-market/provider/lifecycle evidence.
- [ ] Owned disposable COSMO environments deleted and deletion verified; provider fixtures cleaned without deleting customer or unrelated records.
- [ ] Worker-6 generates formal scenarios after that QA, then dry-runs them on an owned sandbox and binds each result to the candidate.
- [ ] Gateway Layer 1 and Layer 2, internal-review decisions, current-tip green CI and independent review recorded. No self-review counted as independent review.
- [ ] Separately authorized new Attachments offer creation completed by Gunnar / offer owner and its genuine product ID supplied and internally reviewed; all listing/legal/support/dependency assets accepted by named owners. Keep `deliverToAppSource` unconfigured until these prerequisites are met.
- [ ] Human release/submission authorization obtained separately. This issue does not authorize creating an offer, submitting it or publishing it.

Foundation is the comparison for evidence discipline: compiler/compiled-artifact gates, immutable inputs and complete release evidence. Its product ID, credentials and approval evidence do not belong to Attachments.

[Microsoft technical validation](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-checklist-submission) covers package signing, non-SUPER permissions, lifecycle and per-country dependency resolution. Check the [Business Central offer setup guidance](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/dynamics-365-business-central-offer-setup) at release time; checklist completion does not submit the offer.
