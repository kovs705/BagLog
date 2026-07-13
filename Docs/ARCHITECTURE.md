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
- [Project description](PROJECT_DESCRIPTION.md) describes the product and user
  journey.

## Current integration status

The persistence package is independently buildable and tested, but it is not
yet wired into the `BagLog` app target or its composition root. Therefore it is
currently a tested foundation, not a user-shippable V1 feature.
