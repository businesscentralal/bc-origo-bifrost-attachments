# Bifrost Attachments

**App name:** Bifrost Attachments (display form *Bifröst viðhengi*)  
**Publisher:** Origo — **Version:** 28.0.0.0 — **Target:** Cloud (BC 28, runtime 17.0)  
**App ID:** `672df32a-a0c5-4a22-b591-0efa38023e95` — **Test app ID:** `7cdb530b-b74b-446b-9ece-80e2b911bfb3`  
**Object ID range:** 10035635–10035684 (tests 96200–96299) — **Namespace:** `Origo.Bifrost.Attachments`

Bifrost Attachments is the storage module of the Bifröst platform. It exposes the Business Central
External File Storage facade (Azure Blob Storage, Azure File Share, SharePoint) as 23 Bifröst
message types, so any external caller can read and write cloud storage, upload large files in
chunks and offload attachments through the same Queue → Task → Data pattern used by the rest of
Bifröst. It is the successor of *Origo Cloud Events Storage*.

---

## Documentation

All public documentation lives in the [businesscentralal/bifrost](https://github.com/businesscentralal/bifrost)
site repository and is published at <https://businesscentralal.github.io/bifrost>. There are no `docs/` or `Help/`
folders in this repository.

| What | Where |
| --- | --- |
| Product documentation (overview, message types, AppSource listing) | <https://businesscentralal.github.io/bifrost/en-us/hnitbjorg/> |
| In-product help (context-sensitive help pages, en-US and is-IS) | <https://businesscentralal.github.io/bifrost/en-us/help/hnitbjorg/> |
| Building on Bifröst (extensibility guide) | <https://businesscentralal.github.io/bifrost/en-us/extensibility/> |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |

Message-type contracts are also served by the app itself at runtime: `Help.Storage.Get` returns
the module directory, and every message type answers its own Markdown help through
`get_message_type_help` / `Help.Implementation.Get`.

Context-sensitive help pages are addressed by Docusaurus slug (`storage-setup`, `storage-card`,
`storage-account-lookup`), resolved against the `contextSensitiveHelpUrl` in `app/app.json`.

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Attachments`) |
| `app/src/MessageTypes/` | Message type implementations and the six domain help codeunits |
| `app/src/Storage/` | Connector interface, production implementation, request helper |
| `app/src/Attachments/` | Attachment offload/restore, link table, table extensions |
| `app/src/Upload/` | Chunked upload session and chunk tables, upload manager, retention policy |
| `app/src/Install/` | `Storage Takeover ori` — data take-over from the published legacy app |
| `test/` | Test app (`Bifrost Attachments - Tests`) |
| `test/reports/` | End-to-end message-type test reports (internal, not published) |
| `.AL-Go/`, `.github/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

---

## Dependencies

| App | ID | Publisher | Version |
| --- | --- | --- | --- |
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.0.0 |

The test app additionally depends on Bifrost Attachments itself and on Microsoft's
Tests-TestLibraries, Application Test Library, Library Assert, Test Runner, Any and
Library Variable Storage.

At runtime, at least one Business Central external file storage connector app (Azure Blob
Storage, Azure File Share or SharePoint) must be installed and configured. Those apps own the
credentials — this app only stores a registered File Account id.

---

## Development

- Open `al.code-workspace` in VS Code.
- Development containers: COSMO Alpaca `bc28-is` (CRONUS IS) and `bc28-w1` (CRONUS International
  Ltd.), both defined in `app/.vscode/launch.json` — git-ignored and the authority for the
  instance ids. Publish and run the unit tests on **both**; select the target with
  `-LaunchConfiguration 'launch: bc28-w1'`.
- Compile locally with `alc.exe` plus CodeCop, UICop and AppSourceCop. Symbols live in
  `app/.alpackages`; test symbols in `test/.alpackages`, including the Bifrost Foundation `.app`.

  ```
  alc.exe /project:app /packagecachepath:app/.alpackages /out:app/output/hnitbjorg.app ^
          /analyzer:<CodeCop.dll> /analyzer:<UICop.dll> /analyzer:<AppSourceCop.dll>
  ```

- Publish and run tests without VS Code (pwsh 7, credential from the user-level env vars
  `BC28IS_USER` / `BC28IS_PASSWORD`, never from files):
  `bc-origo-bifrost-core/tools/Publish-BifrostApp.ps1 -AppFile <.app>` and
  `bc-origo-bifrost-core/tools/Run-BifrostTests.ps1`.
- Command-line `alc` does not raise AS0011 (mandatory affix); AL-Go CI is the gate, so check the
  ` ori` suffix yourself before pushing.
- Standards: [Origo BC Development Standards](https://github.com/OrigoSoftwareSolutions/bc-dev-standards).
  Project rules are in `.claude/CLAUDE.md`; agent context is in [AGENTS.md](AGENTS.md).
- Every object carries the mandatory ` ori` suffix; the brand name is carried by the namespace,
  the app name and the captions, never by an object-name prefix.

---

© 2026 Origo ehf.

<!-- AUTO-UPDATE-START -->
# COSMO Alpaca AL-Go AppSource App Template

[![Use this template](https://github.com/microsoft/AL-Go/assets/10775043/ca1ecc85-2fd3-4ab5-a866-bd2e7e80259d)](https://github.com/new?template_name=Alpaca-AppSource-Template&template_owner=cosmoconsult)

This template repository can be used for managing AppSource Apps for Business Central.

It is a customized version of the [AL-Go-AppSource](https://github.com/microsoft/AL-Go-AppSource) template and is designed to be used with [COSMO Alpaca](https://cosmoconsult.com/cosmo-alpaca).

> [!NOTE]
> If you created this repository using the GitHub web UI (for example by clicking **Use this template** on GitHub.com) instead of creating it from the COSMO Alpaca VS Code extension, you must initialize it using the [COSMO Alpaca VS Code extension](https://marketplace.visualstudio.com/items?itemName=cosmoconsult.cosmo-alpaca). To do this, simply right-click on the repository in VS Code and select _Initialize_.

Please go to https://aka.ms/AL-Go and [COSMO Docs](https://docs.cosmoconsult.com/en-us/cloud-service/alpaca) to learn more.
<!-- AUTO-UPDATE-END -->
