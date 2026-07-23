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
product catalogue are outside the V1 implementation boundary.

The proposed post-V1 server, database, offline sync contract, Raspberry Pi
deployment, and scale-out path are documented separately in
[Backend architecture](BACKEND_ARCHITECTURE.md). That proposal does not change
the Release 1.0 boundary.

## Module boundary

```text
BagLog app
    │
    └── Persistence package
          ├── Models       SwiftData records and relationships
          ├── Types        immutable input and output values
          ├── Store        actor-isolated persistence API
          ├── Schema       SwiftData schema and migrations
          └── Media        Application Support file storage
```

`Persistence` must remain independent of SwiftUI, feature screens, network
clients, StoreKit, and authentication. It stores local data and exposes value
types; it does not decide how a screen looks or when a server request runs.

## V1 rules

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

## Documentation

- [Persistence V1](PERSISTENCE.md) describes the current implementation,
  public API, folder structure, known gaps, and what is intentionally deferred.
- [Create Kit editor](CREATE_KIT_EDITOR.md) documents draft saving, media
  ownership, validation, focus routing, and publication hand-off.
- [Optional account authentication](AUTHENTICATION.md) documents the post-1.0
  Google sign-in boundary, Keychain session lifecycle, configuration, privacy
  review, and production-release blockers.
- [Project description](PROJECT_DESCRIPTION.md) describes the product and user
  journey.
- [Release 1.0](RELEASE_1_0.md) is the shipping scope and acceptance criteria
  for the first local-first release.

## Current integration status

The persistence and media actors are wired into the `BagLog` composition root.
Create Kit owns the local profile prerequisite, continuously saved drafts,
photo staging, item editing, and local publication. My Kits reopens drafts in
that editor and sends published loadouts to read-only detail. Its library uses
status scopes and the shared masonry layout; cover thumbnails come from the
first ordered image asset, with a category fallback when a kit has no cover.
The remaining V1 product gap is the end-to-end fork journey and its catalogue
affordances.

Post-1.0 account work begins with optional Google authentication behind My
Profile. It is composed independently from `Persistence`: guest access remains
the default, local models are unchanged, and no synchronization is implied.
