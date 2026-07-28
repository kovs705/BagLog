# BagLog architecture

## Product direction

BagLog is a local-first app for creating practical loadouts—lists of items for
a specific situation—and adapting another person's published loadout as a new,
independent draft.

The first product release must prove one loop:

```text
create a loadout → add items → publish locally → fork → edit the fork
```

Networking, authentication, subscriptions, discovery, reactions, and a global
product catalogue remain outside the Release 1.0 boundary.

The post-1.0 codebase now contains optional Google authentication and the
Milestone 2 private-draft sync client. Both are development-only additions and
do not change the local-first Release 1.0 path. The server, database, sync
contract, Raspberry Pi deployment, and scale-out path are documented in
[Backend architecture](BACKEND_ARCHITECTURE.md).

## Module boundary

```text
BagLog app
    ├── Application
    │     ├── composes authentication and sync
    │     ├── initializes privacy-limited crash reporting
    │     ├── owns scene/feature/authentication gates
    │     └── presents local sync and conflict state
    ├── Services
    │     ├── Authentication and shared session controller
    │     ├── HTTPS loadout API adapter
    │     └── actor-isolated sync orchestration
    └── Persistence package
          ├── Models       SwiftData aggregates and durable sync records
          ├── Types        immutable input and output values
          ├── Store        actor-isolated persistence API
          ├── Schema       versioned SwiftData schema and migrations
          └── Media        Application Support file storage
```

`Persistence` must remain independent of SwiftUI, feature screens, network
clients, StoreKit, and authentication. It stores local data and exposes value
types; it does not decide how a screen looks or when a server request runs.

## Local data rules

- SwiftData is the only local database.
- `Loadout` owns its items, assets, and fork attribution.
- A fork has new identifiers and never shares mutable item or link records
  with its source.
- Relationships declare inverses and delete rules explicitly.
- A `ModelContext` and `@Model` object stay inside `SwiftDataPersistence`.
- UI and services use stable `UUID`s and immutable values at the module
  boundary.
- The store saves explicitly after a successful operation; it does not rely on
  autosave.
- An eligible local draft write and its logical sync intention commit in the
  same SwiftData transaction.
- Transport DTOs remain in `Services`; `Persistence` has no dependency on
  URLSession, authentication, SwiftUI, or the backend wire format.
- Private sync is account-scoped. Attempts retain their exact encoded body,
  idempotency key, operation, and expected revision across retries.
- Remote conflicts and tombstones never silently overwrite unsent local work.

## Documentation

- [Persistence](PERSISTENCE.md) describes the V3 local schema, durable sync
  state, migration, public boundaries, and intentionally deferred concerns.
- [Create Kit editor](CREATE_KIT_EDITOR.md) documents draft saving, media
  ownership, validation, focus routing, and publication hand-off.
- [Optional account authentication](AUTHENTICATION.md) documents Google
  sign-in, the shared Keychain-backed session controller, synchronization
  integration, privacy review, and production-release blockers.
- [Error reporting](ERROR_REPORTING.md) documents the Sentry boundary, local
  and CI configuration, privacy constraints, dSYM upload, and verification.
- [Project description](PROJECT_DESCRIPTION.md) describes the product and user
  journey.
- [Release 1.0](RELEASE_1_0.md) is the shipping scope and acceptance criteria
  for the first local-first release.

## Current integration status

The persistence and media actors are wired into the `BagLog` composition root.
Create Kit owns the local profile prerequisite, continuously saved drafts,
photo staging, item editing, local publication, and explicit conflict
resolution. My Kits reopens drafts in that editor, shows local synchronization
state, and sends published loadouts to read-only detail.

Optional Google authentication and private-draft synchronization share one
session actor. The sync coordinator runs only in a foreground DEBUG build when
`BAGLOG_PRIVATE_SYNC_ENABLED` is exactly `YES` (or the UI-test override is
present), a BagLog session is valid, and a local/remote profile scope has been
established. Guest and disabled-flag workflows make no sync requests.

Sentry starts at the composition root when a DSN is configured. It receives
crashes and explicitly reported, sanitized handled failures; replay,
performance, logs, metrics, network breadcrumbs, screenshots, view hierarchy,
and automatic session tracking remain disabled.

SwiftData remains the immediate source of truth. The engine first resumes any
immutable in-flight attempt, then pushes new durable work, bootstraps or pulls
remote changes, and advances cursors only with the transaction that applies a
complete page. Conflicts are durable and offer keep-local, use-remote,
duplicate-local, and keep-deleted outcomes.
