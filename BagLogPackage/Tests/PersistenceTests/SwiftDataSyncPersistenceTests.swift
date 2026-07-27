import Foundation
import Testing
@testable import Persistence

extension PersistenceTestPlan {
@Suite("SwiftData sync persistence")
struct SwiftDataSyncPersistenceTests {
    private let now = Date(timeIntervalSince1970: 2_100_000_000)

    @Test("An eligible save and its logical sync change commit together")
    func eligibleSaveEnqueuesChange() async throws {
        let setup = try await makeScopedPersistence()

        let loadout = try await setup.persistence.saveLoadout(
            SaveLoadoutCommand(
                ownerID: setup.profile.id,
                title: "Offline draft",
                tagNames: ["TRAVEL", " travel "]
            )
        )
        let pending = try #require(
            await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
        )

        #expect(pending.loadoutID == loadout.id)
        #expect(pending.kind == .upsert)
        #expect(pending.expectedRevision == nil)
        #expect(LoadoutSyncProjection(snapshot: pending.snapshot).tags == ["travel"])
        #expect(loadout.syncState == .waiting)
    }

    @Test("A materialized attempt is immutable while newer edits queue separately")
    func immutableAttemptSurvivesNewerEdit() async throws {
        let setup = try await makeScopedPersistence()
        let loadout = try await saveDraft(in: setup)
        let pending = try #require(
            await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
        )
        let immutableBody = Data(#"{"stable":true}"#.utf8)
        let idempotencyKey = UUID()
        let attempt = try await setup.persistence.materializeAttempt(
            MaterializeLoadoutAttemptCommand(
                pendingChangeID: pending.id,
                idempotencyKey: idempotencyKey,
                encodedBody: immutableBody
            )
        )
        try await setup.persistence.markAttemptStarted(
            idempotencyKey: idempotencyKey,
            at: now
        )

        _ = try await setup.persistence.saveLoadout(
            SaveLoadoutCommand(
                id: loadout.id,
                ownerID: setup.profile.id,
                title: "Newer local edit"
            )
        )

        let resumed = try #require(
            await setup.persistence.nextMutationAttempt(
                scopeID: setup.scope.id,
                at: now
            )
        )
        let newerChange = try #require(
            await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
        )

        #expect(resumed.idempotencyKey == idempotencyKey)
        #expect(resumed.encodedBody == immutableBody)
        #expect(resumed.localGeneration == attempt.localGeneration)
        #expect(newerChange.localGeneration > attempt.localGeneration)
        #expect(newerChange.snapshot.title == "Newer local edit")
    }

    @Test("Deleting after a create may have been sent preserves create then delete")
    func unknownCreateResultPrecedesDelete() async throws {
        let setup = try await makeScopedPersistence()
        let loadout = try await saveDraft(in: setup)
        let createChange = try #require(
            await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
        )
        let createKey = UUID()
        _ = try await setup.persistence.materializeAttempt(
            MaterializeLoadoutAttemptCommand(
                pendingChangeID: createChange.id,
                idempotencyKey: createKey,
                encodedBody: Data("create".utf8)
            )
        )
        try await setup.persistence.markAttemptStarted(
            idempotencyKey: createKey,
            at: now
        )

        try await setup.persistence.deleteLoadout(id: loadout.id)

        let resumedCreate = try #require(
            await setup.persistence.nextMutationAttempt(
                scopeID: setup.scope.id,
                at: now
            )
        )
        let pendingDelete = try #require(
            await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
        )
        #expect(resumedCreate.operation == .create)
        #expect(pendingDelete.kind == .delete)
        #expect(try await setup.persistence.loadout(id: loadout.id) == nil)

        let aggregate = remoteAggregate(
            from: createChange.snapshot,
            revision: 1
        )
        try await setup.persistence.acknowledgeMutation(
            LoadoutMutationAcknowledgement(
                idempotencyKey: createKey,
                result: .aggregate(aggregate),
                acknowledgedAt: now
            )
        )
        let refreshedDelete = try #require(
            await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
        )
        #expect(refreshedDelete.expectedRevision == 1)
    }

    @Test("A concurrent remote edit creates a durable conflict and can keep local")
    func concurrentEditConflict() async throws {
        let setup = try await makeScopedPersistence()
        let synchronized = try await acknowledgeInitialCreate(in: setup)
        try await establishCursor(in: setup)

        _ = try await setup.persistence.saveLoadout(
            SaveLoadoutCommand(
                id: synchronized.id,
                ownerID: setup.profile.id,
                title: "This device"
            )
        )
        let remote = remoteAggregate(
            id: synchronized.id,
            title: "Other device",
            revision: 2
        )
        try await setup.persistence.applyChangePage(
            scopeID: setup.scope.id,
            changes: [
                RemoteLoadoutChange(
                    cursor: 1,
                    resourceID: synchronized.id,
                    revision: 2,
                    changedAt: now,
                    payload: .upsert(remote)
                )
            ],
            nextCursor: 1,
            hasMore: false,
            appliedAt: now
        )

        let conflict = try #require(
            await setup.persistence.conflict(loadoutID: synchronized.id)
        )
        #expect(conflict.localSnapshot.title == "This device")
        guard case let .aggregate(remoteVersion) = conflict.remoteVersion else {
            Issue.record("Expected a remote aggregate")
            return
        }
        #expect(remoteVersion.projection.title == "Other device")

        let resolved = try #require(
            await setup.persistence.resolveConflict(
                loadoutID: synchronized.id,
                resolution: .useThisDevice,
                at: now
            )
        )
        let rebasedChange = try #require(
            await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
        )
        #expect(resolved.title == "This device")
        #expect(resolved.syncState == .waiting)
        #expect(rebasedChange.expectedRevision == 2)
        #expect(try await setup.persistence.conflict(loadoutID: synchronized.id) == nil)
    }

    @Test("A concurrent remote edit can explicitly replace the local projection")
    func concurrentEditCanUseServerVersion() async throws {
        let setup = try await makeScopedPersistence()
        let synchronized = try await acknowledgeInitialCreate(in: setup)
        try await establishCursor(in: setup)
        _ = try await setup.persistence.saveLoadout(
            SaveLoadoutCommand(
                id: synchronized.id,
                ownerID: setup.profile.id,
                title: "This device"
            )
        )
        let remote = remoteAggregate(
            id: synchronized.id,
            title: "Server choice",
            revision: 2
        )
        try await setup.persistence.applyChangePage(
            scopeID: setup.scope.id,
            changes: [
                RemoteLoadoutChange(
                    cursor: 1,
                    resourceID: synchronized.id,
                    revision: 2,
                    changedAt: now,
                    payload: .upsert(remote)
                )
            ],
            nextCursor: 1,
            hasMore: false,
            appliedAt: now
        )

        let resolved = try #require(
            await setup.persistence.resolveConflict(
                loadoutID: synchronized.id,
                resolution: .useServerVersion,
                at: now
            )
        )

        #expect(resolved.title == "Server choice")
        #expect(resolved.remoteRevision == 2)
        #expect(resolved.syncState == .synced)
        #expect(try await setup.persistence.conflict(loadoutID: synchronized.id) == nil)
        #expect(
            try await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
                == nil
        )
    }

    @Test("Remote projection updates preserve local-only assets")
    func remoteProjectionPreservesAssets() async throws {
        let setup = try await makeScopedPersistence()
        let assetID = UUID()
        let thumbnail = Data([1, 2, 3])
        let synchronized = try await acknowledgeInitialCreate(
            in: setup,
            assets: [
                LoadoutAssetCommand(
                    id: assetID,
                    mediaKind: .image,
                    caption: "Local only",
                    localFileName: "local.jpg",
                    thumbnailData: thumbnail
                )
            ]
        )
        try await establishCursor(in: setup)
        let remote = remoteAggregate(
            id: synchronized.id,
            title: "Remote title",
            revision: 2
        )

        try await setup.persistence.applyChangePage(
            scopeID: setup.scope.id,
            changes: [
                RemoteLoadoutChange(
                    cursor: 1,
                    resourceID: synchronized.id,
                    revision: 2,
                    changedAt: now,
                    payload: .upsert(remote)
                )
            ],
            nextCursor: 1,
            hasMore: false,
            appliedAt: now
        )
        let updated = try #require(
            await setup.persistence.loadout(id: synchronized.id)
        )

        #expect(updated.title == "Remote title")
        #expect(updated.assets.map(\.id) == [assetID])
        #expect(updated.assets[0].localFileName == "local.jpg")
        #expect(updated.assets[0].thumbnailData == thumbnail)
    }

    @Test("Publishing detaches the remote projection and retains the local kit")
    func publishingDetachesWithoutDeletingLocalAggregate() async throws {
        let setup = try await makeScopedPersistence()
        let synchronized = try await acknowledgeInitialCreate(
            in: setup,
            assets: [
                LoadoutAssetCommand(
                    mediaKind: .image,
                    localFileName: "cover.jpg"
                )
            ]
        )
        try await establishCursor(in: setup)
        let published = try await setup.persistence.saveLoadout(
            SaveLoadoutCommand(
                id: synchronized.id,
                ownerID: setup.profile.id,
                title: synchronized.title,
                visibility: .public,
                status: .published,
                items: synchronized.items.map(itemCommand),
                assets: synchronized.assets.map(assetCommand)
            )
        )
        let pendingDelete = try #require(
            await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
        )
        #expect(pendingDelete.kind == .delete)
        #expect(pendingDelete.deleteReason == .eligibilityDetach)
        #expect(published.status == .published)

        let key = UUID()
        _ = try await setup.persistence.materializeAttempt(
            MaterializeLoadoutAttemptCommand(
                pendingChangeID: pendingDelete.id,
                idempotencyKey: key,
                encodedBody: nil
            )
        )
        let tombstone = RemoteLoadoutTombstone(
            id: synchronized.id,
            revision: 2,
            deletedAt: now
        )
        try await setup.persistence.acknowledgeMutation(
            LoadoutMutationAcknowledgement(
                idempotencyKey: key,
                result: .tombstone(tombstone),
                acknowledgedAt: now
            )
        )
        try await setup.persistence.applyChangePage(
            scopeID: setup.scope.id,
            changes: [
                RemoteLoadoutChange(
                    cursor: 1,
                    resourceID: synchronized.id,
                    revision: 2,
                    changedAt: now,
                    payload: .delete(tombstone)
                )
            ],
            nextCursor: 1,
            hasMore: false,
            appliedAt: now
        )
        let retained = try #require(
            await setup.persistence.loadout(id: synchronized.id)
        )

        #expect(retained.status == .published)
        #expect(retained.visibility == .public)
        #expect(retained.assets.map(\.localFileName) == ["cover.jpg"])
        #expect(retained.syncState == .local)
    }

    @Test("A stale local delete is visible and can rebase on the server revision")
    func staleDeleteCanBeResolvedExplicitly() async throws {
        let setup = try await makeScopedPersistence()
        let synchronized = try await acknowledgeInitialCreate(in: setup)
        try await setup.persistence.deleteLoadout(id: synchronized.id)
        let pendingDelete = try #require(
            await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
        )
        let key = UUID()
        _ = try await setup.persistence.materializeAttempt(
            MaterializeLoadoutAttemptCommand(
                pendingChangeID: pendingDelete.id,
                idempotencyKey: key,
                encodedBody: nil
            )
        )
        try await setup.persistence.markAttemptStarted(
            idempotencyKey: key,
            at: now
        )
        try await setup.persistence.recordMutationConflict(
            idempotencyKey: key,
            remoteVersion: .aggregate(
                remoteAggregate(
                    id: synchronized.id,
                    title: "Edited elsewhere",
                    revision: 2
                )
            ),
            detectedAt: now
        )

        let restored = try #require(
            await setup.persistence.loadout(id: synchronized.id)
        )
        let conflict = try #require(
            await setup.persistence.conflict(loadoutID: synchronized.id)
        )
        #expect(restored.syncState == .conflicted)
        #expect(conflict.localOperation == .delete)
        #expect(conflict.localDeleteReason == .userDeleted)

        let resolution = try await setup.persistence.resolveConflict(
            loadoutID: synchronized.id,
            resolution: .useThisDevice,
            at: now
        )
        let rebasedDelete = try #require(
            await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
        )
        #expect(resolution == nil)
        #expect(rebasedDelete.kind == .delete)
        #expect(rebasedDelete.expectedRevision == 2)
        #expect(try await setup.persistence.loadout(id: synchronized.id) == nil)
    }

    @Test("A remote tombstone completes an equivalent pending local delete")
    func remoteTombstoneReconcilesPendingDelete() async throws {
        let setup = try await makeScopedPersistence()
        let synchronized = try await acknowledgeInitialCreate(in: setup)
        try await establishCursor(in: setup)
        try await setup.persistence.deleteLoadout(id: synchronized.id)
        let tombstone = RemoteLoadoutTombstone(
            id: synchronized.id,
            revision: 2,
            deletedAt: now
        )

        try await setup.persistence.applyChangePage(
            scopeID: setup.scope.id,
            changes: [
                RemoteLoadoutChange(
                    cursor: 1,
                    resourceID: synchronized.id,
                    revision: 2,
                    changedAt: now,
                    payload: .delete(tombstone)
                )
            ],
            nextCursor: 1,
            hasMore: false,
            appliedAt: now
        )

        #expect(try await setup.persistence.loadout(id: synchronized.id) == nil)
        #expect(
            try await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
                == nil
        )
        #expect(try await setup.persistence.conflict(loadoutID: synchronized.id) == nil)
    }

    @Test("A delete/edit race can clone the local graph with fresh stable IDs")
    func tombstoneConflictClonesDraft() async throws {
        let setup = try await makeScopedPersistence()
        let synchronized = try await acknowledgeInitialCreate(
            in: setup,
            items: [
                LoadoutItemCommand(
                    title: "Camera",
                    links: [ItemLinkCommand(urlString: "https://example.com")]
                )
            ]
        )
        try await establishCursor(in: setup)
        _ = try await setup.persistence.saveLoadout(
            SaveLoadoutCommand(
                id: synchronized.id,
                ownerID: setup.profile.id,
                title: "Offline edit",
                items: synchronized.items.map(itemCommand)
            )
        )
        let tombstone = RemoteLoadoutTombstone(
            id: synchronized.id,
            revision: 2,
            deletedAt: now
        )
        try await setup.persistence.applyChangePage(
            scopeID: setup.scope.id,
            changes: [
                RemoteLoadoutChange(
                    cursor: 1,
                    resourceID: synchronized.id,
                    revision: 2,
                    changedAt: now,
                    payload: .delete(tombstone)
                )
            ],
            nextCursor: 1,
            hasMore: false,
            appliedAt: now
        )

        let clone = try #require(
            await setup.persistence.resolveConflict(
                loadoutID: synchronized.id,
                resolution: .saveAsNewDraft,
                at: now
            )
        )

        #expect(clone.id != synchronized.id)
        #expect(clone.items[0].id != synchronized.items[0].id)
        #expect(clone.items[0].links[0].id != synchronized.items[0].links[0].id)
        #expect(try await setup.persistence.loadout(id: synchronized.id) == nil)
        #expect(
            try await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)?
                .loadoutID == clone.id
        )
    }

    @Test("A failed page does not advance its cursor or keep partial content")
    func pullPageRollsBackAtomically() async throws {
        let setup = try await makeScopedPersistence()
        let unsafe = RemoteLoadoutAggregate(
            projection: LoadoutSyncProjection(
                id: UUID(),
                title: "Unsafe",
                summary: "",
                category: "other",
                items: [
                    LoadoutSyncItem(
                        id: UUID(),
                        title: "Link",
                        category: nil,
                        brand: nil,
                        model: nil,
                        notes: nil,
                        quantity: 1,
                        isEssential: false,
                        links: [
                            LoadoutSyncLink(
                                id: UUID(),
                                urlString: "http://example.com",
                                label: nil
                            )
                        ]
                    )
                ],
                tags: []
            ),
            revision: 1,
            createdAt: now,
            updatedAt: now
        )

        await #expect(throws: PersistenceError.invalidURL) {
            try await setup.persistence.applyBootstrapPage(
                scopeID: setup.scope.id,
                loadouts: [unsafe],
                cursor: 10,
                nextAfter: nil,
                hasMore: false,
                appliedAt: now
            )
        }

        let scope = try #require(
            await setup.persistence.syncScope(id: setup.scope.id)
        )
        #expect(scope.cursor == nil)
        #expect(try await setup.persistence.loadout(id: unsafe.projection.id) == nil)
    }

    private func makeScopedPersistence() async throws -> Setup {
        let persistence = SwiftDataPersistence(
            modelContainer: try BagLogModelContainer.make(isStoredInMemoryOnly: true)
        )
        let profile = try await persistence.saveProfile(
            SaveUserProfileCommand(handle: "owner", displayName: "Owner")
        )
        let scope = try await persistence.activateSyncScope(
            remoteProfileID: UUID(),
            localProfileID: profile.id,
            at: now
        )
        return Setup(persistence: persistence, profile: profile, scope: scope)
    }

    private func saveDraft(in setup: Setup) async throws -> LoadoutSnapshot {
        try await setup.persistence.saveLoadout(
            SaveLoadoutCommand(
                ownerID: setup.profile.id,
                title: "Initial draft"
            )
        )
    }

    private func acknowledgeInitialCreate(
        in setup: Setup,
        items: [LoadoutItemCommand] = [],
        assets: [LoadoutAssetCommand] = []
    ) async throws -> LoadoutSnapshot {
        let loadout = try await setup.persistence.saveLoadout(
            SaveLoadoutCommand(
                ownerID: setup.profile.id,
                title: "Synchronized",
                items: items,
                assets: assets
            )
        )
        let pending = try #require(
            await setup.persistence.oldestPendingChange(scopeID: setup.scope.id)
        )
        let key = UUID()
        _ = try await setup.persistence.materializeAttempt(
            MaterializeLoadoutAttemptCommand(
                pendingChangeID: pending.id,
                idempotencyKey: key,
                encodedBody: Data("body".utf8)
            )
        )
        try await setup.persistence.acknowledgeMutation(
            LoadoutMutationAcknowledgement(
                idempotencyKey: key,
                result: .aggregate(remoteAggregate(from: loadout, revision: 1)),
                acknowledgedAt: now
            )
        )
        return try #require(await setup.persistence.loadout(id: loadout.id))
    }

    private func establishCursor(in setup: Setup) async throws {
        try await setup.persistence.applyBootstrapPage(
            scopeID: setup.scope.id,
            loadouts: [],
            cursor: 0,
            nextAfter: nil,
            hasMore: false,
            appliedAt: now
        )
    }

    private func remoteAggregate(
        from snapshot: LoadoutSnapshot,
        revision: Int64
    ) -> RemoteLoadoutAggregate {
        RemoteLoadoutAggregate(
            projection: LoadoutSyncProjection(snapshot: snapshot),
            revision: revision,
            createdAt: now,
            updatedAt: now
        )
    }

    private func remoteAggregate(
        id: UUID,
        title: String,
        revision: Int64
    ) -> RemoteLoadoutAggregate {
        RemoteLoadoutAggregate(
            projection: LoadoutSyncProjection(
                id: id,
                title: title,
                summary: "",
                category: "other",
                items: [],
                tags: []
            ),
            revision: revision,
            createdAt: now,
            updatedAt: now
        )
    }

    private func itemCommand(
        _ item: LoadoutItemSnapshot
    ) -> LoadoutItemCommand {
        LoadoutItemCommand(
            id: item.id,
            title: item.title,
            category: item.category,
            brand: item.brand,
            model: item.model,
            notes: item.notes,
            quantity: item.quantity,
            isEssential: item.isEssential,
            links: item.links.map {
                ItemLinkCommand(
                    id: $0.id,
                    urlString: $0.urlString,
                    label: $0.label
                )
            }
        )
    }

    private func assetCommand(
        _ asset: LoadoutAssetSnapshot
    ) -> LoadoutAssetCommand {
        LoadoutAssetCommand(
            id: asset.id,
            mediaKind: asset.mediaKind,
            caption: asset.caption,
            localFileName: asset.localFileName,
            remoteURLString: asset.remoteURLString,
            thumbnailData: asset.thumbnailData
        )
    }

    private struct Setup {
        let persistence: SwiftDataPersistence
        let profile: UserProfileSnapshot
        let scope: LoadoutSyncScopeSnapshot
    }
}
}
