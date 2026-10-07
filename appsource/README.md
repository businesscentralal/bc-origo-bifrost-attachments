# AppSource offer: Bifrost Attachments

Everything to enter in Partner Center for this offer, page by page, as Microsoft's offer pages ask
for it (Business Central offer, checked 06.10.2026). Built from the app's main branch and the
documentation. No message type names, as on the public site. Review before publishing.

## Files in this folder

| File | Use | Partner Center page |
|---|---|---|
| `logo-216.png` | Large logo, PNG, in the style of Bifrost Foundation's | Offer listing › Logos |
| `screenshots/*.png` | 3 screenshots, 1280 × 720 PNG (3 to 5 required) | Offer listing › Screenshots |
| `description.html` | Description with the allowed HTML tags | Offer listing › Description |
| `description.txt` | The same as plain text | (for review) |
| `product-sheet.pdf` | One-page marketing sheet (1 to 3 PDFs required) | Offer listing › Supporting documents |

## 1. Offer setup

| Field | Value |
|---|---|
| Offer alias | Bifrost Attachments |
| Customer leads / listing option | Same as Bifrost Foundation |

## 2. Properties

| Field | Value | Subcategories |
|---|---|---|
| Primary category | Productivity | Document & File Management |
| Secondary category | Infrastructure Services | Storage & Data Management |
| Industry | (leave empty: not industry-specific) | |
| App version | The version of the `.app` you upload (the pipeline sets it) | |
| Terms and conditions (URL) | https://docs.bifrost.origo.is/en-us/licensing/eula/ | |

## 3. Offer listing

| Field | Value | Length / limit |
|---|---|---|
| Name | Bifrost Attachments | 19 / 200 |
| Search results summary | Keep Business Central files in Azure Blob, File Share or SharePoint, reachable from any process. | 96 / 100 |
| Description | `description.html` | 1908 / 5,000 |
| Search keywords | Cloud storage, SharePoint, File management | 3 / 3 |
| Products your app works with | Dynamics 365 Business Central, SharePoint | 2 / 3 |
| Help link | https://docs.bifrost.origo.is/en-us/apps/ | must differ from Support URL |
| Privacy policy link | https://docs.bifrost.origo.is/en-us/licensing/privacy/ | |
| Support contact (name, e-mail, phone, URL) | Same as Bifrost Foundation; Support URL https://www.origo.is/ | not shown to customers |
| Engineering contact | Same as Bifrost Foundation | not shown to customers |
| Supporting documents | `product-sheet.pdf` | 1 to 3 PDFs |
| Logo | `logo-216.png` | PNG |
| Screenshots | see below | 3 to 5, 1280 × 720 PNG |
| Videos | optional; none yet | up to 4 |

Links use the documentation's own domain, docs.bifrost.origo.is. The app has no page of its own on the
site yet, so the help link goes to the app list; change it to the app's page once that is published.
The app's `app.json` still points to the old github.io address, which GitHub forwards to the new domain.

Microsoft's logo guidance says no text on the logo; Bifrost Foundation's logo has text, so this one
follows Foundation for a consistent family.

### Screenshots and captions

| File | Caption |
|---|---|
| `screenshots/01-wizard.png` | A setup wizard connects Azure Blob, Azure File Share or SharePoint. |
| `screenshots/02-setup.png` | All storage connections in one place, set up once for every process. |
| `screenshots/03-http.png` | Ready in a few steps: the wizard checks outbound access for you. |

Taken in the Bifrost sandbox (CRONUS demo company, demo data), 06.10.2026. The company name, user
names, e-mail addresses and IDs were replaced before capture.

## 4. Availability

Markets: the same as Bifrost Foundation.

## 5. Technical configuration

Upload the app's `.app` file from the release build. Dependency: Bifrost Foundation.

## 6. Supplemental content

| Field | Value |
|---|---|
| Supported editions | Essentials and Premium |
| Key usage scenario, test accounts, test app | No longer used in validation (Microsoft); leave empty unless Partner Center requires it |

## Description (as in `description.txt`)

```
Keep your Business Central files in cloud storage, and reach them from any process.

Bifrost Attachments connects Business Central to Azure Blob Storage, Azure File Share and SharePoint. Other systems, assistants and Business Central processes all use the same storage connections, set up once. It is an add-on to Bifrost Foundation.

Who it is for
Business Central customers with many attachments or document flows, and administrators who want a smaller database and one place for files.

What it does
- Makes the database smaller: moves document and incoming document attachments out to storage and brings them back when needed. Files still open normally in Business Central.
- Works with files and folders: list, download, upload, copy, move and delete files and folders in any storage connection.
- Attaches a stored file to a record: a customer, vendor, fixed asset, document or incoming document, without uploading it again.
- Handles large files: sent in pieces and put together in storage.
- Uses the standard connectors: Azure Blob Storage, Azure File Share or SharePoint, through Business Central's own connector apps.

Requirements and pricing
- Microsoft Dynamics 365 Business Central 28.0 or later, Essentials or Premium.
- Bifrost Foundation, available separately on AppSource.
- At least one Business Central file storage connector app, for example the Azure Blob Storage Connector by Microsoft.
- For prices, contact Origo (https://www.origo.is/) or your Business Central partner.
- If you are a partner, contact The App Channel (https://www.theappchannel.com/).

Bifrost Attachments does not replace Business Central or its extensions. It makes their data and business logic available to the people, routines and AI platforms your organisation already uses.
```

---
Drafted with the help of Claude (Anthropic); review before publishing. Origo's AI policy (STE-0002):
the person who publishes is responsible for the content.
