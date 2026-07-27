import Foundation
import SwiftData
import Testing
@testable import Persistence

extension PersistenceTestPlan {
@Suite("Persistence migration")
struct PersistenceMigrationTests {
    @Test("V1 data and valid decimal revisions migrate into the current schema")
    func migratesPopulatedV1Store() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let storeURL = directory.appendingPathComponent("BagLog.store")
        let identifiers = Identifiers()

        try autoreleasepool {
            try makeV1Fixture(at: storeURL, identifiers: identifiers)
        }

        let persistence = SwiftDataPersistence(
            modelContainer: try BagLogModelContainer.make(storeURL: storeURL)
        )
        let profile = try #require(
            await persistence.profile(id: identifiers.profileID)
        )
        let loadout = try #require(
            await persistence.loadout(id: identifiers.loadoutID)
        )

        #expect(profile.handle == "owner")
        #expect(loadout.id == identifiers.loadoutID)
        #expect(loadout.items.map(\.id) == [identifiers.itemID])
        #expect(loadout.items[0].links.map(\.id) == [identifiers.linkID])
        #expect(loadout.assets.map(\.id) == [identifiers.assetID])
        #expect(loadout.tagNames == ["Travel"])
        #expect(loadout.remoteRevision == 17)
    }

    @Test("V2 sync queue state migrates into V3")
    func migratesPopulatedV2Store() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let storeURL = directory.appendingPathComponent("BagLog.store")
        let identifiers = Identifiers()

        try autoreleasepool {
            try makeV2Fixture(at: storeURL, identifiers: identifiers)
        }

        let persistence = SwiftDataPersistence(
            modelContainer: try BagLogModelContainer.make(storeURL: storeURL)
        )
        let scope = try #require(
            await persistence.syncScope(id: identifiers.scopeID)
        )
        let attempt = try #require(
            await persistence.nextMutationAttempt(
                scopeID: identifiers.scopeID,
                at: .distantFuture
            )
        )
        let loadout = try #require(
            await persistence.loadout(id: identifiers.loadoutID)
        )

        #expect(scope.remoteProfileID == identifiers.remoteProfileID)
        #expect(attempt.idempotencyKey == identifiers.idempotencyKey)
        #expect(attempt.pendingChangeID == identifiers.pendingChangeID)
        #expect(loadout.remoteRevision == 7)
        #expect(loadout.syncState == .waiting)
    }

    private func makeV1Fixture(
        at storeURL: URL,
        identifiers: Identifiers
    ) throws {
        let container = try BagLogModelContainer.withSchemaConstructionLock {
            let schema = Schema(versionedSchema: BagLogSchemaV1.self)
            let configuration = ModelConfiguration(
                "BagLog",
                schema: schema,
                url: storeURL
            )
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let profile = BagLogSchemaV1.UserProfile(
            id: identifiers.profileID,
            handle: "owner",
            displayName: "Owner"
        )
        let loadout = BagLogSchemaV1.Loadout(
            id: identifiers.loadoutID,
            ownerID: profile.id,
            title: "Migrated kit",
            summary: "",
            category: .travel,
            visibility: .private
        )
        loadout.owner = profile
        loadout.remoteRevision = "17"
        loadout.items = [
            BagLogSchemaV1.LoadoutItem(
                id: identifiers.itemID,
                title: "Passport",
                sortIndex: 0
            )
        ]
        loadout.items[0].links = [
            BagLogSchemaV1.ItemLink(
                id: identifiers.linkID,
                urlString: "https://example.com/passport",
                sortIndex: 0
            )
        ]
        loadout.assets = [
            BagLogSchemaV1.LoadoutAsset(
                id: identifiers.assetID,
                mediaKind: .image,
                sortIndex: 0,
                localFileName: "cover.jpg",
                thumbnailData: Data([1, 2, 3])
            )
        ]
        loadout.tags = [
            BagLogSchemaV1.Tag(name: "Travel", normalizedName: "travel")
        ]
        context.insert(profile)
        context.insert(loadout)
        try context.save()
    }

    private func makeV2Fixture(
        at storeURL: URL,
        identifiers: Identifiers
    ) throws {
        let container = try BagLogModelContainer.withSchemaConstructionLock {
            let schema = Schema(versionedSchema: BagLogSchemaV2.self)
            let configuration = ModelConfiguration(
                "BagLog",
                schema: schema,
                url: storeURL
            )
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let now = Date(timeIntervalSince1970: 2_100_000_000)
        let profile = BagLogSchemaV2.UserProfile(
            id: identifiers.profileID,
            handle: "owner",
            displayName: "Owner"
        )
        let loadout = BagLogSchemaV2.Loadout(
            id: identifiers.loadoutID,
            ownerID: profile.id,
            title: "Queued kit",
            summary: "",
            category: .travel,
            visibility: .private
        )
        loadout.owner = profile
        let scope = BagLogSchemaV2.LoadoutSyncScope(
            id: identifiers.scopeID,
            remoteProfileID: identifiers.remoteProfileID,
            localProfileID: profile.id,
            createdAt: now
        )
        let metadata = BagLogSchemaV2.LoadoutSyncMetadata(
            loadoutID: loadout.id,
            scopeID: scope.id,
            acknowledgedRevision: 7,
            localGeneration: 2,
            updatedAt: now
        )
        let pendingChange = BagLogSchemaV2.PendingLoadoutChange(
            id: identifiers.pendingChangeID,
            scopeID: scope.id,
            loadoutID: loadout.id,
            kind: .upsert,
            deleteReason: nil,
            localGeneration: 2,
            snapshotData: Data([1]),
            createdAt: now
        )
        let attempt = BagLogSchemaV2.LoadoutMutationAttempt(
            idempotencyKey: identifiers.idempotencyKey,
            pendingChangeID: pendingChange.id,
            scopeID: scope.id,
            loadoutID: loadout.id,
            operation: .replace,
            expectedRevision: 7,
            encodedBody: Data("{}".utf8),
            snapshotData: Data([1]),
            localGeneration: 2
        )

        context.insert(profile)
        context.insert(loadout)
        context.insert(scope)
        context.insert(metadata)
        context.insert(pendingChange)
        context.insert(attempt)
        try context.save()
    }

    private struct Identifiers {
        let profileID = UUID()
        let loadoutID = UUID()
        let itemID = UUID()
        let linkID = UUID()
        let assetID = UUID()
        let remoteProfileID = UUID()
        let scopeID = UUID()
        let pendingChangeID = UUID()
        let idempotencyKey = UUID()
    }
}
}
