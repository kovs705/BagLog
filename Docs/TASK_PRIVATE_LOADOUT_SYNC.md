# Task: Implement Milestone 2 Private Loadout Sync

**Status:** Ready for implementation  
**Target release:** Post-1.0 / Milestone 2  
**Primary surfaces:** Persistence, Services, app composition, My Kits, Create Kit  
**Backend dependency:** Implemented in BagLogBackend API `0.4.0`  
**Rollout:** Development feature flag, disabled by default

## Goal

Add authenticated, offline-first synchronization for private draft loadouts.
SwiftData remains the immediate source of truth: editing, saving, opening, and
deleting a draft must work without a network connection. A background sync
actor later pushes durable local mutations and applies remote changes without
silently losing either side of a concurrent edit.

This task closes the iOS portion of backend Milestone 2. It does not turn the
app into an online-first client and must not make authentication or networking
a prerequisite for existing local workflows.

## Required outcome

When the development flag is enabled and a BagLog session is signed in:

1. local private draft changes are committed to SwiftData together with a
   durable sync intention;
2. the app pushes those intentions with stable UUIDs, immutable idempotency
   attempts, and optimistic revisions;
3. the app bootstraps and incrementally pulls the account's private loadouts;
4. exact retries survive cancellation, network failure, and app relaunch;
5. remote tombstones remove acknowledged local copies;
6. stale concurrent edits become explicit, durable conflicts; and
7. signing out or switching accounts cannot send one account's data to another.

When the flag is disabled, the app behaves exactly as it does today and starts
no sync requests.

## Source of truth

Before writing production code, replace the stale
`Backend/OpenAPI/baglog-v1.yaml` snapshot in this repository with the canonical
backend contract:

```text
BagLogBackend/api/openapi.yaml
```

The iOS copy is currently API `0.1.0`; the implemented backend contract is
`0.4.0`. Do not implement Milestone 2 from the old proposal in
`Docs/BACKEND_ARCHITECTURE.md` where it conflicts with API `0.4.0`.

Read these backend documents with the refreshed OpenAPI file:

- `BagLogBackend/docs/decisions/0007-private-loadout-synchronization.md`
- `BagLogBackend/docs/roadmap.md`
- `BagLogBackend/docs/security/threat-model.md`
- `BagLogBackend/docs/development.md`

## Current iOS foundation

Reuse the existing boundaries:

- `SwiftDataPersistence` is an actor and explicitly saves local transactions.
- `Loadout`, `LoadoutItem`, and `ItemLink` already use app-owned UUIDs.
- `Loadout` already contains placeholder `remoteID`, `remoteRevision`,
  `lastSyncedAt`, and `syncState` fields.
- Create Kit continuously saves valid drafts through `BagLogPersisting`.
- `AuthenticationStore` restores and rotates the BagLog token pair through the
  Keychain-backed session vault.
- the app base URL is already injected through `BAGLOG_API_BASE_URL`.

The placeholders are not a complete sync design. In particular:

- `saveLoadout` does not atomically enqueue an outbox entry;
- `deleteLoadout` physically deletes the only local record;
- `remoteRevision` is a `String?`, while API revisions are positive `Int64`
  values and ETags are their quoted wire representation;
- authentication does not expose a concurrency-safe valid-access-token
  provider to other services;
- there is no durable account scope, cursor, mutation attempt, or conflict
  record; and
- the current iOS OpenAPI snapshot predates the implemented endpoints.

## Scope

Milestone 2 synchronizes only:

- private draft loadouts;
- ordered items;
- ordered HTTPS item links; and
- normalized tags.

The complete supported graph is one conflict and transaction boundary.

Do not send local-only properties that are absent from `LoadoutWrite`,
including:

- `ownerID`;
- visibility or publication state;
- local or remote media fields;
- assets and thumbnails;
- fork attribution;
- archive/publication timestamps; or
- local sync state.

Published, archived, public, media-bearing, and fork-specific behavior stays
local until the corresponding later backend milestone exists. A draft may
still contain local photos, but this task neither uploads nor removes them.

Treat the API graph as a synchronized projection of the richer local
aggregate. Applying a remote upsert may replace title, summary, category,
items, links, normalized tags, revision, and server timestamps, but it must
preserve local-only assets, thumbnails, fork metadata, local ownership, and
other fields outside the projection.

Only `private` + `draft` is eligible. When an already-synchronized draft is
published or archived locally:

- preserve the local non-draft aggregate and all local-only data;
- durably remove its private server projection with a revisioned delete;
- distinguish that detach operation from a user deleting the local aggregate;
  the returning remote tombstone must not delete the published/archived local
  record; and
- if a create result is still unknown, resolve/replay the create before
  deleting it.

The backend cannot recreate the same loadout UUID while its soft-deleted row is
retained. A later transition from published/archived back to a synchronized
private draft must therefore be disallowed for this milestone or explicitly
clone the aggregate with fresh loadout, item, and link UUIDs.

## Architecture

Keep transport, orchestration, persistence, and UI responsibilities separate:

```text
BagLog/Application
├── composes one session controller and one sync engine
├── starts/stops sync from auth, feature-flag, and scene state
└── presents local sync/conflict state

Services/Sources
├── Session/
│   └── valid access-token and refresh coordination
└── Sync/
    ├── BagLogLoadoutAPI actor
    ├── transport DTOs and strict response validation
    └── LoadoutSyncEngine actor

BagLogPackage/Sources/Persistence
├── local loadout aggregate
├── account-scoped sync metadata
├── logical pending changes and immutable attempts
├── durable conflicts
└── atomic local-write, acknowledgement, pull, and tombstone APIs
```

`Persistence` must remain independent of `Services`, SwiftUI, URLSession, and
authentication. Define persistence input/output value types for the sync
engine; never pass an `@Model` instance across the actor boundary.

Transport DTOs belong in `Services` and must not become SwiftData records.
Mapping between DTOs and persistence values also belongs in `Services`.

## Authentication and account scope

### Shared session controller

Refactor the live authentication composition so authentication and sync share
one actor that owns access to the current BagLog session. It must:

- return a valid access token, refreshing shortly before expiry;
- deduplicate concurrent refreshes;
- atomically save a rotated pair through `AuthenticationSessionStoring`;
- allow one forced refresh and one retry after an authenticated request gets
  `401`;
- clear the session and notify the main-actor authentication state when refresh
  is rejected; and
- never expose the refresh token to the sync engine or API request models.

Do not let each API client independently load and rotate Keychain credentials.
Do not parse identity or authorization decisions from JWT claims on the
client.

### Remote profile preflight

The loadout backend requires the authenticated account to have a profile.
Before starting bootstrap or push:

1. call `GET /v1/profile`;
2. if it exists, use the returned profile UUID as the durable remote account
   scope;
3. if it returns `404` and a valid local profile exists, create the remote
   profile through `POST /v1/profile` using its handle, display name, and bio;
4. if no local profile exists, leave sync idle and surface a safe action to
   create the existing local profile first; and
5. treat a handle conflict as an actionable profile setup failure, not as an
   excuse to create a random identity.

Profile field synchronization is not part of this task. The remote profile UUID
only partitions sync state and proves which authenticated account owns the
remote loadouts.

### Account isolation

Persist a sync-scope record that binds:

- remote profile UUID;
- local profile UUID;
- bootstrap/incremental cursor state; and
- timestamps and recoverable status.

Every pending mutation, immutable attempt, and conflict must belong to that
scope. On sign-out, cancel in-flight requests and stop sync, but keep local
loadouts and durable scoped state. On a later sign-in:

- resume only when the returned remote profile UUID matches the scope;
- never process another scope's queue with the new token; and
- never silently rebind a loadout already associated with another remote
  profile.

Existing unbound private drafts owned by the selected local profile may be
bound to the first enabled development scope in one explicit persistence
operation. Record the binding before sending anything. A production rollout
must replace this development migration with an intentional user-facing
opt-in/import decision.

## Development feature flag

Add `BAGLOG_PRIVATE_SYNC_ENABLED` to checked-in configuration with a default of
`NO`, expose it through the generated Info.plist, and parse it through a focused
configuration value.

Requirements:

- sync is effective only in `DEBUG` builds;
- malformed or absent values resolve to disabled;
- the normal local/guest path remains unchanged while disabled;
- UI tests can override the flag with a launch argument and injected fakes; and
- enabling the flag does not bypass the signed-in and profile-preflight gates.

Do not add a remote feature-flag dependency for this milestone.

## Persistence design

### Schema migration

Add a new versioned SwiftData schema and migration stage. Never edit
`BagLogSchemaV1` in place or fall back to deleting an incompatible store.
Exercise migration from a populated V1 store in tests.

Add durable models equivalent to:

```text
LoadoutSyncScope
  remoteProfileID
  localProfileID
  cursor
  bootstrapCursor
  bootstrapAfter
  bootstrapState
  lastCompletedAt

PendingLoadoutChange
  id
  scopeID
  loadoutID
  kind                 upsert | delete
  localGeneration
  createdAt

LoadoutMutationAttempt
  idempotencyKey
  scopeID
  loadoutID
  operation            create | replace | delete
  expectedRevision
  encodedBody          nil only for delete
  localGeneration
  state
  firstAttemptedAt
  retryNotBefore

LoadoutConflict
  scopeID
  loadoutID
  baseRevision
  localSnapshot
  remoteSnapshot       or remote tombstone
  detectedAt
```

Names may change, but the represented state and transaction boundaries may
not.

Store backend revisions as positive `Int64` values. Parse and validate the
strong ETag separately, then require it to equal the response body's
`revision`. Migrate any valid decimal placeholder in `remoteRevision`; reject
invalid or overflowing values as unsynchronized state. `remoteID` must never
become a second resource identity: the local `Loadout.id` is the remote UUID.

### Atomic local writes

Extend the persistence API so an eligible local save and its pending sync
change commit in the same `ModelContext.save()`. The UI still receives the
local snapshot immediately and never awaits a network call.

Likewise, local deletion must atomically:

1. preserve the loadout UUID, last acknowledged revision, scope, and required
   recovery data in the outbox; and
2. remove the visible local aggregate.

If either part fails, neither part may commit.

An eligibility-detach delete uses the same durable network guarantees, but it
keeps the visible local non-draft aggregate. Record the delete reason so a
pulled tombstone can distinguish detach from local user deletion.

The Create Kit 600 ms autosave can produce many local generations. Coalesce
only logical changes that have never been materialized into a network attempt.
Once an attempt might have reached the server, its idempotency key, method,
path UUID, expected revision, and exact encoded body are immutable.

### Durable exact-retry rule

Materialize an immutable attempt before the first request and save it before
network I/O. Every retry of that attempt must use the same:

- UUID `Idempotency-Key`;
- HTTP operation and resource UUID;
- `If-Match` revision, when required; and
- body bytes.

After acknowledgement, compare the attempt's `localGeneration` with the
current local generation. If newer local edits exist, retain/materialize the
next logical change against the newly acknowledged revision.

Never reuse an idempotency key for a changed body. Never discard an attempt
because the request task was cancelled or the app moved to the background.

Special delete case: if a locally created loadout is deleted before its create
attempt has ever started, both unsent intentions may be removed locally. If
the create might have reached the server, retry that exact create to learn its
result, then send a revisioned delete.

## API client contract

Implement the API manually with `URLSession` and `Codable`; do not add an
OpenAPI generator or third-party network package for this slice.

Use an ephemeral URL session, HTTPS-only base URL validation, same-origin
redirect rejection, structured cancellation, bounded response bodies, and
safe domain errors. Reuse or extract the hardened behavior currently present
in `AuthenticationAPI` rather than duplicating subtly different policies.

### Aggregate endpoints

| Operation | Request requirements | Success |
| --- | --- | --- |
| Create | `POST /v1/loadouts`, bearer token, UUID `Idempotency-Key`, full body | `201`, aggregate, strong `ETag` |
| Read | `GET /v1/loadouts/{id}`, bearer token | `200`, aggregate, strong `ETag` |
| Replace | `PUT /v1/loadouts/{id}`, bearer token, UUID `Idempotency-Key`, strong `If-Match`, full body | `200`, aggregate, strong `ETag` |
| Delete | `DELETE /v1/loadouts/{id}`, bearer token, UUID `Idempotency-Key`, strong `If-Match`, empty body | `200`, tombstone, strong `ETag` |

The replace body UUID must equal the path UUID. The backend accepts at most
512 KiB for a loadout body.

`LoadoutWrite` limits:

- title: nonblank, at most 160 characters;
- summary: at most 4,000 characters;
- category: nonblank, at most 80 characters;
- items: at most 100;
- tags: at most 30, unique after normalization;
- item title: nonblank, at most 240 characters;
- item category: optional, at most 120 characters;
- brand/model: optional, at most 160 characters each;
- notes: optional, at most 4,000 characters;
- quantity: `1...10_000`;
- links per item: at most 10;
- link URL: absolute HTTPS, at most 2,048 characters; and
- link label: optional, at most 160 characters.

Mirror these constraints at the persistence/editor boundary where practical,
while still treating the server as authoritative. Encode absent optional item
and link values as JSON `null`. Normalize tags to lowercase, trim them,
deduplicate them, and use a deterministic sorted order.

### Bootstrap

Initial request:

```http
GET /v1/sync/bootstrap?limit=20
```

Continuation requests keep the first page's `cursor` fixed and send the
returned `next_after`:

```http
GET /v1/sync/bootstrap?cursor=<fixed>&after=<next_after>&limit=20
```

Validate:

- all continuation pages return the same fixed cursor;
- `has_more == true` always has a non-null `next_after`;
- a continuation advances `next_after`; and
- page sizes do not exceed 20.

Persist bootstrap progress after each successfully applied page so a relaunch
can safely continue. Promote the fixed cursor to the incremental cursor only
after the final bootstrap page has been applied. Then immediately drain
incremental changes from that cursor; this closes the race with writes that
committed while bootstrap was paging.

### Incremental changes

Request:

```http
GET /v1/sync/changes?cursor=<cursor>&limit=20
```

Apply ordered pages until `has_more` is false. An `upsert` must include the full
aggregate snapshot; a `delete` must have a null `loadout`. Reject internally
inconsistent entries, regressing cursors, resource-ID mismatches, or revision
mismatches without advancing the durable cursor.

Apply every page and its `next_cursor` in one SwiftData transaction. Advancing
the cursor before all changes commit is prohibited.

### Stable errors

Decode the backend error object (`code`, `message`, `trace_id`) but expose only
safe, stable client errors. The following codes require explicit behavior:

| Status/code | Client behavior |
| --- | --- |
| `401 invalid_token` | Force one session refresh and retry once; if rejected, stop sync and return to signed out. |
| `409 profile_required` | Run or surface the remote-profile preflight; do not loop. |
| `404 loadout_not_found` | Reconcile through the pull feed; if a local mutation exists, preserve it and create a conflict/recovery state. |
| `409 mutation_in_progress` | Retry the exact attempt after `Retry-After` or a bounded default. |
| `409 idempotency_conflict` | Stop the attempt as a non-retryable invariant failure and preserve diagnostic metadata without request content. |
| `409 loadout_conflict` | Preserve the local change and surface a stable conflict/failure. |
| `412 revision_mismatch` | Fetch the current aggregate, then persist local and remote versions as a conflict. |
| `428 revision_required` | Treat as a client invariant failure; never retry without fixing the stored attempt. |
| `400 invalid_cursor` | Treat as corrupted/invalid local cursor state and restart bootstrap without deleting pending local changes. |
| `410 cursor_expired` | Reset pull/bootstrap metadata and start a fresh bootstrap; retain every pending mutation and conflict. |
| `500 internal_error` or transport failure | Retry later with bounded exponential backoff and jitter. |

Do not display the server's raw `message`, response body, token, item link, or
private loadout data. A `trace_id` may be retained for an explicit support
action, but must not be combined with private content in logs.

## Sync engine behavior

Implement one actor per app process. It serializes state transitions for the
active scope and never launches two requests for the same mutation.

Recommended cycle:

1. verify feature flag, foreground policy, authenticated session, and remote
   profile scope;
2. resume any immutable attempt whose result is unknown;
3. materialize and push the oldest eligible logical local change;
4. continue until the current push queue is acknowledged, delayed, failed, or
   conflicted;
5. resume or start bootstrap if no usable cursor exists;
6. drain incremental changes to a stable page; and
7. sleep until triggered or until a persisted retry deadline.

Trigger a cycle after:

- successful authentication restoration/sign-in;
- an eligible local save or delete;
- app activation;
- a user-requested refresh; and
- a retry deadline while the app is active.

Network reachability may be a retry hint, not a source of truth. Do not busy
loop, use detached tasks, or keep retry state only in memory.

### Applying remote upserts

For each remote aggregate:

- if there is no local record or pending local change, insert/replace the local
  synchronized projection and acknowledge its revision;
- preserve all local-only fields when replacing an existing projection and
  assign a newly bootstrapped aggregate to the scope's local profile;
- never downgrade or overwrite a published/archived local aggregate with a
  remote private draft;
- if the revision is at or below the acknowledged local remote revision,
  ignore it as a duplicate;
- if it is the acknowledgement/echo of the exact pushed generation, update
  sync metadata without replacing newer local edits; and
- if a newer remote revision intersects an unsent local generation, preserve
  both versions in `LoadoutConflict`.

Server timestamps are metadata for synchronized state. They must not be used as
a last-writer-wins conflict policy.

### Applying remote tombstones

- With no pending local change, remove the local aggregate and acknowledge the
  tombstone transactionally.
- For a completed eligibility detach, keep the local published/archived
  aggregate and clear only its remote binding/sync metadata.
- With a pending local change, preserve the local snapshot and remote
  tombstone as a conflict.
- A duplicate or older tombstone is harmless and must not recreate work.

### Conflict resolution

Add a minimal explicit conflict state in My Kits and the draft editor. For a
remote upsert conflict, a user must be able to inspect that both versions exist
and choose:

- **Use This Device:** keep the preserved local graph, rebase it on the fetched
  server revision, and enqueue a new replace with a fresh idempotency key; or
- **Use Server Version:** replace the visible local graph with the preserved
  remote graph, while retaining a recoverable local copy until resolution
  commits.

When the remote side is a tombstone, the old UUID cannot be created again
while the backend retains the soft-deleted row. Offer:

- **Save as New Draft:** clone the preserved local graph with fresh loadout,
  item, and link UUIDs, resolve the old aggregate as deleted, and enqueue the
  clone as a create; or
- **Accept Deletion:** remove the preserved local graph and resolve the
  conflict.

Conflict resolution must be another atomic persistence operation. Never
automatically choose by timestamp.

## User experience

Synchronization is supportive state, not a blocking editor phase:

- local saves continue to show as saved when SwiftData commits;
- optionally distinguish waiting, synced, failed, and conflicted states in My
  Kits without implying that unsynced means unsaved;
- expose a retry action for a retryable sync failure;
- show an explicit conflict badge/action;
- do not present repeated alerts for background retry failures; and
- preserve VoiceOver labels and Dynamic Type behavior.

The current `LoadoutSyncState` may be expanded or replaced by derived state,
but it must not collapse durable queue/conflict facts into a lossy enum.

## Security and privacy requirements

- Authenticate every sync endpoint. Never send a request before final remote
  profile scope is known.
- Never log authorization headers, token values, refresh credentials, private
  loadout bodies, links, mutation body bytes, cursors associated with content,
  or local/remote conflict snapshots.
- Never persist access or refresh tokens in SwiftData.
- Accept only the configured HTTPS origin and reject credential-forwarding
  redirects.
- Treat all decoded UUIDs, URLs, timestamps, revisions, ETags, cursors, array
  counts, and error bodies as attacker-controlled.
- Bound response data before decoding; use the refreshed OpenAPI limits and a
  documented small allowance for page envelopes.
- Keep mutation bodies protected by normal iOS data protection and scoped to
  the correct remote profile.
- Do not send local filenames, thumbnail bytes, media metadata, fork
  attribution, visibility, or publication state.
- Cancellation stops current work but never deletes durable retry state.

## Proposed file map

Exact names may change while preserving these ownership boundaries:

```text
Services/Sources/Session/
  BagLogSessionController.swift
  BagLogAccessTokenProviding.swift

Services/Sources/Sync/
  BagLogLoadoutAPI.swift
  BagLogLoadoutAPIProviding.swift
  BagLogLoadoutDTOs.swift
  BagLogSyncError.swift
  LoadoutSyncEngine.swift
  LoadoutSyncEngineDependencies.swift

BagLogPackage/Sources/Persistence/Sync/
  LoadoutSyncScope.swift
  PendingLoadoutChange.swift
  LoadoutMutationAttempt.swift
  LoadoutConflict.swift
  LoadoutSyncValues.swift
  SwiftDataPersistence+Sync.swift

BagLog/Application/Sync/
  LoadoutSyncComposition.swift
  LoadoutSyncConfiguration.swift
  LoadoutSyncCoordinator.swift

BagLogTests/Sync/
  BagLogLoadoutAPITests.swift
  LoadoutSyncEngineTests.swift
  LoadoutSyncCoordinatorTests.swift

BagLogPackage/Tests/PersistenceTests/
  SwiftDataSyncPersistenceTests.swift
  PersistenceMigrationTests.swift
```

## Implementation sequence

### Phase 1 — contract and session foundation

- [ ] Refresh the checked-in OpenAPI snapshot to backend API `0.4.0`.
- [ ] Add strict loadout, tombstone, bootstrap, change-page, and error DTOs.
- [ ] Extract shared HTTPS/redirect/body-limit behavior from authentication.
- [ ] Introduce the shared session controller and keep existing auth tests green.
- [ ] Add remote profile preflight and stable account-scope identity.
- [ ] Add the debug-only, default-off feature flag.

### Phase 2 — durable persistence

- [ ] Add the V2 schema and migration from populated V1 data.
- [ ] Add account scope, cursor/bootstrap progress, logical change, immutable
      attempt, and conflict records.
- [ ] Make eligible save plus enqueue atomic.
- [ ] Make visible delete plus durable tombstone intention atomic.
- [ ] Add page-application APIs that update the cursor in the same transaction.
- [ ] Add acknowledgement and explicit conflict-resolution transactions.
- [ ] Cover private-draft eligibility exit without deleting the local
      published/archived aggregate.

### Phase 3 — API and orchestration

- [ ] Implement aggregate create/read/replace/delete.
- [ ] Implement paged bootstrap and incremental changes.
- [ ] Implement exact retry, persisted backoff, and cancellation handling.
- [ ] Reconcile echoes, duplicates, remote changes, and tombstones.
- [ ] Restart bootstrap safely after cursor expiry.
- [ ] Wire auth, scene, local-change, refresh, and retry triggers.

### Phase 4 — presentation and end-to-end proof

- [ ] Add non-blocking waiting/synced/failed/conflict presentation.
- [ ] Add explicit conflict resolution for remote upsert and deletion cases.
- [ ] Add deterministic UI-test composition with no real network or Keychain.
- [ ] Run two-client integration scenarios against the development backend.
- [ ] Update `Docs/ARCHITECTURE.md`, `Docs/PERSISTENCE.md`,
      `Docs/AUTHENTICATION.md`, and `Docs/BACKEND_ARCHITECTURE.md` so they
      describe the implemented, feature-flagged boundary and API `0.4.0`.
- [ ] Keep the feature disabled in normal and Release builds.

## Tests

### API client

Use an injected `URLProtocol` and verify:

- method, path, query, headers, body, timeout, and bearer token;
- stable UUID `Idempotency-Key` and quoted `If-Match`;
- ETag/body revision agreement;
- create/read/replace/delete success decoding;
- `Idempotency-Replayed: true`;
- bootstrap continuation with fixed cursor and advancing `next_after`;
- ordered incremental pages and nullability rules;
- every stable error mapping listed above;
- one refresh/retry after `401`, with no infinite loop;
- same-origin redirects only;
- malformed JSON, wrong content shapes, oversized responses, timeout, offline,
  and cancellation; and
- secret/private-value redaction from errors and descriptions.

### Persistence

Use in-memory containers plus a stored V1 fixture and verify:

- V1-to-V2 migration preserves profiles, loadouts, items, links, tags, assets,
  UUIDs, order, and local files;
- save/enqueue and delete/enqueue are atomic;
- logical changes coalesce only before attempt materialization;
- an attempted mutation's canonical fields are immutable;
- acknowledgements retain a newer local generation;
- a pull page and cursor commit or roll back together;
- duplicate upserts/tombstones are idempotent;
- remote changes never overwrite a pending local generation;
- cursor reset retains outbox and conflict records;
- account scopes cannot read or claim each other's work; and
- both conflict-resolution choices preserve the selected graph.

### Sync engine

Inject API, persistence, session provider, clock, UUID generator, random jitter,
and sleeper. Cover:

- offline create, edit, delete, relaunch, and eventual acknowledgement;
- unknown create result followed by exact replay;
- duplicate mutation response;
- local edits arriving while a prior generation is in flight;
- `mutation_in_progress` and persisted `Retry-After`;
- concurrent-device stale replace and stale delete;
- echo versus genuine remote conflict;
- bootstrap across multiple pages plus changes committed during bootstrap;
- app termination between applying a page and advancing its cursor;
- 90-day cursor expiry and full bootstrap without outbox loss;
- remote tombstone with and without a local pending edit;
- draft-to-published detach, including an unknown create result;
- sign-out during a request;
- rejected refresh;
- signing into a different account with an old scoped queue; and
- malformed/reordered server data without cursor advancement.

### Manual development matrix

Use two app installations/simulators and the development backend:

1. Create and edit offline, terminate the app, reconnect, and verify one remote
   aggregate with the latest local graph.
2. Interrupt a mutation after sending it, relaunch, and verify an exact
   idempotency replay rather than a duplicate revision.
3. Edit the same loadout independently on two clients and verify an explicit
   conflict with both graphs recoverable.
4. Delete on one client while the other has an offline edit and verify neither
   side is silently lost.
5. Expire/reset the development cursor and verify bootstrap recovery retains
   pending local edits.
6. Sign out, sign in as another account, and verify no request contains the
   first account's loadout IDs or bodies.
7. Disable the flag and verify zero sync traffic and unchanged guest/local
   behavior.

## Acceptance criteria

- [ ] The app remains fully usable as a guest and while offline.
- [ ] SwiftData commits local edits before any network dependency.
- [ ] The feature is disabled by default and cannot activate in Release.
- [ ] Only authenticated private draft fields defined by API `0.4.0` are sent.
- [ ] Remote projection updates preserve local-only media and attribution.
- [ ] Publishing/archiving removes the private server projection without
      deleting the local aggregate.
- [ ] Stable loadout, item, and link UUIDs survive every round trip.
- [ ] A local write/delete and its durable sync intention commit atomically.
- [ ] Every possibly sent attempt retries with identical canonical inputs.
- [ ] Push acknowledgements cannot overwrite a newer local generation.
- [ ] Bootstrap is paged with a fixed watermark and followed by incremental
      changes.
- [ ] Pull cursors advance only with successfully committed page contents.
- [ ] Cursor expiry restarts bootstrap without deleting pending local work.
- [ ] Duplicate changes and idempotency replays are harmless.
- [ ] Concurrent edits and delete/edit races preserve both sides and surface an
      explicit resolution.
- [ ] Account switching cannot process or expose another scope's queue.
- [ ] Session refresh is deduplicated and rejected refresh stops sync safely.
- [ ] No tokens, authorization headers, loadout contents, links, mutation
      bodies, or conflict snapshots are logged.
- [ ] Migration preserves an existing V1 store.
- [ ] Automated and two-client manual milestone exit scenarios pass without
      silent data loss.

## Verification

After persistence-only changes:

```sh
cd BagLogPackage
swift test
swift build --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  --triple arm64-apple-ios18.0-simulator
```

After target paths, build configuration, or app integration changes:

```sh
tuist generate --no-open
xcodebuild -workspace BagLog.xcworkspace \
  -scheme BagLog \
  -destination 'platform=iOS Simulator,name=<available iOS 26 simulator>' \
  test
```

Also run the manual development matrix against a disposable/development
backend. Unit tests cannot prove app-relaunch durability, Keychain/session
rotation, real PostgreSQL idempotency replay, or two-client conflict behavior.

## Out of scope

- Public/published/archived loadout synchronization.
- Media upload, remote media URLs, thumbnails, and asset associations.
- Server-side fork and attribution synchronization.
- Public catalogue, search, moderation, reports, and profile blocking.
- Field-level merge, CRDTs, or timestamp-based last-writer-wins.
- Background execution guarantees while iOS suspends the app.
- Production enablement or a production migration/consent experience.
- New third-party networking, retry, database, or feature-flag dependencies.
- Backend endpoint or schema changes.

## Definition of done

Milestone 2 is complete end to end when the development-flagged iOS sync actor
passes offline retry, duplicate mutation, concurrent edit, process restart,
cursor expiry, tombstone, and account-boundary scenarios against the
implemented backend without silent data loss, while all existing local-only
workflows continue to work with the flag off.
