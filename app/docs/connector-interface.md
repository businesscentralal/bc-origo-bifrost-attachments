---
title: Storage connector contract
audience: developers
keywords: storage, connector, interface, registered account, attachments
locale: en-US
---

All registered Business Central External File Storage connectors use the same interface
path. Attachments does not select behavior by connector ID, read provider account tables,
pin connector builds or depend on specific connector apps. The connector owns account
access, credentials, backend path limits and errors.

## Reuse a registered account for shared attachment storage

An attachment link is protected within its registered account: storage backend, opaque
connector value, account GUID and canonical logical path. Setups using that same account
can have different base paths; matching and moved-link updates use the complete logical
path and preserve stored spelling.

Separate account registrations are separate scopes, even if configured to reach the same
physical files. Reuse one registered account for shared attachment locations. The BC 28
interface exposes no physical identity, URL decoding or case comparison contract.
Attachments does not infer those rules: use consistent logical path spelling for linked files.

## Validate application inputs and delegate provider rules

Attachments retains generic traversal, control-character, root-deletion and field-length
checks, including the complete base-prefixed 2048-character path capacity. Provider-specific
length, depth, character and account requirements belong to the selected connector.
Connector failures use the existing structured Bifröst error response.

## Copy or move to a new destination

Copy and move refuse an exact self-transfer with InvalidParameter. They also ask the
connector whether the destination already exists and refuse an existing file with
PreconditionFailed before writing. This applies equally to every connector and lets the
connector recognize its own case or encoded aliases. Choose a new destination;
Storage.File.Create retains its existing write behavior.

The existence preflight is not an atomic create-if-absent operation; the BC 28 interface
does not expose that guarantee.

## Preserve linked content when a move fails

The application's storage interface declares whether linked moves preserve the source
on failure. The platform facade cannot guarantee a remote move outcome, so linked moves
through it remain refused with a structured error. The test backend supports linked moves
because it preserves source bytes on failure; an extra copied destination may still
require cleanup. This capability does not claim transactional rollback of remote storage.

## Verify the abstraction

Run tools/Test-ConnectorAbstraction.ps1 and its -SelfTest mode. The source guard rejects
connector-ID dispatch, provider account introspection and specific connector dependencies.
The test app registers an arbitrary connector through Microsoft's interface to verify
delegation, account isolation, error propagation and transfer refusal without installing
a particular provider.
