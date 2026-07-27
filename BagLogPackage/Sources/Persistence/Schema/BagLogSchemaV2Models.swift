import Foundation
import SwiftData

extension BagLogSchemaV2 {
    @Model
    final class UserProfile {
        #Index<UserProfile>([\.handle])

        var id: UUID
        var handle: String
        var displayName: String
        var bio: String?
        var avatarAssetID: UUID?
        var createdAt: Date
        var updatedAt: Date

        @Relationship(deleteRule: .cascade, inverse: \Loadout.owner)
        var loadouts: [Loadout] = []

        init(
            id: UUID = UUID(),
            handle: String,
            displayName: String,
            bio: String? = nil,
            avatarAssetID: UUID? = nil,
            createdAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.handle = handle
            self.displayName = displayName
            self.bio = bio
            self.avatarAssetID = avatarAssetID
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class Loadout {
        #Index<Loadout>(
            [\.updatedAt],
            [\.statusRaw],
            [\.visibilityRaw],
            [\.categoryRaw],
            [\.ownerID]
        )

        var id: UUID
        var ownerID: UUID
        var remoteID: String?
        var title: String
        var summary: String
        var categoryRaw: String
        var visibilityRaw: String
        var statusRaw: String
        var syncStateRaw: String
        var createdAt: Date
        var updatedAt: Date
        var publishedAt: Date?
        var archivedAt: Date?
        var lastSyncedAt: Date?
        var remoteRevision: String?

        var owner: UserProfile?

        @Relationship(deleteRule: .cascade, inverse: \LoadoutItem.loadout)
        var items: [LoadoutItem] = []

        @Relationship(deleteRule: .cascade, inverse: \LoadoutAsset.loadout)
        var assets: [LoadoutAsset] = []

        @Relationship(deleteRule: .cascade, inverse: \ForkOrigin.loadout)
        var forkOrigin: ForkOrigin?

        @Relationship(deleteRule: .nullify, inverse: \Tag.loadouts)
        var tags: [Tag] = []

        init(
            id: UUID = UUID(),
            ownerID: UUID,
            title: String,
            summary: String,
            category: LoadoutCategory,
            visibility: LoadoutVisibility,
            status: LoadoutStatus = .draft,
            syncState: LoadoutSyncState = .local,
            createdAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.ownerID = ownerID
            self.title = title
            self.summary = summary
            categoryRaw = category.rawValue
            visibilityRaw = visibility.rawValue
            statusRaw = status.rawValue
            syncStateRaw = syncState.rawValue
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class LoadoutItem {
        #Index<LoadoutItem>([\.sortIndex])

        var id: UUID
        var title: String
        var category: String?
        var brand: String?
        var model: String?
        var notes: String?
        var quantity: Int
        var sortIndex: Int
        var isEssential: Bool
        var loadout: Loadout?

        @Relationship(deleteRule: .cascade, inverse: \ItemLink.item)
        var links: [ItemLink] = []

        init(
            id: UUID = UUID(),
            title: String,
            category: String? = nil,
            brand: String? = nil,
            model: String? = nil,
            notes: String? = nil,
            quantity: Int = 1,
            sortIndex: Int,
            isEssential: Bool = false
        ) {
            self.id = id
            self.title = title
            self.category = category
            self.brand = brand
            self.model = model
            self.notes = notes
            self.quantity = quantity
            self.sortIndex = sortIndex
            self.isEssential = isEssential
        }
    }

    @Model
    final class ItemLink {
        var id: UUID
        var urlString: String
        var label: String?
        var sortIndex: Int
        var item: LoadoutItem?

        init(
            id: UUID = UUID(),
            urlString: String,
            label: String? = nil,
            sortIndex: Int
        ) {
            self.id = id
            self.urlString = urlString
            self.label = label
            self.sortIndex = sortIndex
        }
    }

    @Model
    final class LoadoutAsset {
        var id: UUID
        var mediaKindRaw: String
        var sortIndex: Int
        var caption: String?
        var localFileName: String?
        var remoteURLString: String?

        @Attribute(.externalStorage)
        var thumbnailData: Data?

        var loadout: Loadout?

        init(
            id: UUID = UUID(),
            mediaKind: LoadoutMediaKind,
            sortIndex: Int,
            caption: String? = nil,
            localFileName: String? = nil,
            remoteURLString: String? = nil,
            thumbnailData: Data? = nil
        ) {
            self.id = id
            mediaKindRaw = mediaKind.rawValue
            self.sortIndex = sortIndex
            self.caption = caption
            self.localFileName = localFileName
            self.remoteURLString = remoteURLString
            self.thumbnailData = thumbnailData
        }
    }

    @Model
    final class Tag {
        #Unique<Tag>([\.normalizedName])
        #Index<Tag>([\.normalizedName])

        var id: UUID
        var name: String
        var normalizedName: String
        var createdAt: Date
        var updatedAt: Date
        var loadouts: [Loadout] = []

        init(
            id: UUID = UUID(),
            name: String,
            normalizedName: String,
            createdAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.normalizedName = normalizedName
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class ForkOrigin {
        var sourceLoadoutID: UUID
        var sourceRemoteID: String?
        var rootLoadoutID: UUID
        var sourceTitle: String
        var sourceAuthorHandle: String
        var forkedAt: Date
        var loadout: Loadout?

        init(
            sourceLoadoutID: UUID,
            sourceRemoteID: String?,
            rootLoadoutID: UUID,
            sourceTitle: String,
            sourceAuthorHandle: String,
            forkedAt: Date = .now
        ) {
            self.sourceLoadoutID = sourceLoadoutID
            self.sourceRemoteID = sourceRemoteID
            self.rootLoadoutID = rootLoadoutID
            self.sourceTitle = sourceTitle
            self.sourceAuthorHandle = sourceAuthorHandle
            self.forkedAt = forkedAt
        }
    }

    @Model
    final class SavedLoadout {
        #Index<SavedLoadout>([\.profileID], [\.loadoutID])

        var id: UUID
        var profileID: UUID
        var loadoutID: UUID
        var savedAt: Date

        init(
            id: UUID = UUID(),
            profileID: UUID,
            loadoutID: UUID,
            savedAt: Date = .now
        ) {
            self.id = id
            self.profileID = profileID
            self.loadoutID = loadoutID
            self.savedAt = savedAt
        }
    }

    @Model
    final class LoadoutSyncScope {
        #Unique<LoadoutSyncScope>([\.remoteProfileID])
        #Index<LoadoutSyncScope>([\.localProfileID], [\.updatedAt])

        var id: UUID
        var remoteProfileID: UUID
        var localProfileID: UUID
        var cursor: Int64?
        var bootstrapCursor: Int64?
        var bootstrapAfter: UUID?
        var bootstrapStateRaw: String
        var lastCompletedAt: Date?
        var lastFailureCode: String?
        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID,
            remoteProfileID: UUID,
            localProfileID: UUID,
            createdAt: Date
        ) {
            self.id = id
            self.remoteProfileID = remoteProfileID
            self.localProfileID = localProfileID
            bootstrapStateRaw = LoadoutBootstrapState.notStarted.rawValue
            self.createdAt = createdAt
            updatedAt = createdAt
        }
    }

    @Model
    final class LoadoutSyncMetadata {
        #Unique<LoadoutSyncMetadata>([\.loadoutID])
        #Index<LoadoutSyncMetadata>([\.scopeID], [\.updatedAt])

        var id: UUID
        var loadoutID: UUID
        var scopeID: UUID?
        var acknowledgedRevision: Int64?
        var localGeneration: Int64
        var remoteCreatedAt: Date?
        var remoteUpdatedAt: Date?
        var lastSyncedAt: Date?
        var isDetached: Bool
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            loadoutID: UUID,
            scopeID: UUID?,
            acknowledgedRevision: Int64? = nil,
            localGeneration: Int64 = 0,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.loadoutID = loadoutID
            self.scopeID = scopeID
            self.acknowledgedRevision = acknowledgedRevision
            self.localGeneration = localGeneration
            isDetached = false
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class PendingLoadoutChange {
        #Unique<PendingLoadoutChange>([\.id])
        #Index<PendingLoadoutChange>(
            [\.scopeID],
            [\.loadoutID],
            [\.createdAt]
        )

        var id: UUID
        var scopeID: UUID
        var loadoutID: UUID
        var kindRaw: String
        var deleteReasonRaw: String?
        var localGeneration: Int64
        var snapshotData: Data
        var createdAt: Date

        init(
            id: UUID = UUID(),
            scopeID: UUID,
            loadoutID: UUID,
            kind: PendingLoadoutChangeKind,
            deleteReason: LoadoutDeleteReason?,
            localGeneration: Int64,
            snapshotData: Data,
            createdAt: Date
        ) {
            self.id = id
            self.scopeID = scopeID
            self.loadoutID = loadoutID
            kindRaw = kind.rawValue
            deleteReasonRaw = deleteReason?.rawValue
            self.localGeneration = localGeneration
            self.snapshotData = snapshotData
            self.createdAt = createdAt
        }
    }

    @Model
    final class LoadoutMutationAttempt {
        #Unique<LoadoutMutationAttempt>([\.idempotencyKey])
        #Index<LoadoutMutationAttempt>(
            [\.scopeID],
            [\.loadoutID],
            [\.retryNotBefore]
        )

        var idempotencyKey: UUID
        var pendingChangeID: UUID
        var scopeID: UUID
        var loadoutID: UUID
        var operationRaw: String
        var expectedRevision: Int64?
        var encodedBody: Data?
        var snapshotData: Data
        var localGeneration: Int64
        var stateRaw: String
        var firstAttemptedAt: Date?
        var retryNotBefore: Date?
        var attemptCount: Int
        var failureCode: String?
        var traceID: String?

        init(
            idempotencyKey: UUID,
            pendingChangeID: UUID,
            scopeID: UUID,
            loadoutID: UUID,
            operation: LoadoutMutationOperation,
            expectedRevision: Int64?,
            encodedBody: Data?,
            snapshotData: Data,
            localGeneration: Int64
        ) {
            self.idempotencyKey = idempotencyKey
            self.pendingChangeID = pendingChangeID
            self.scopeID = scopeID
            self.loadoutID = loadoutID
            operationRaw = operation.rawValue
            self.expectedRevision = expectedRevision
            self.encodedBody = encodedBody
            self.snapshotData = snapshotData
            self.localGeneration = localGeneration
            stateRaw = LoadoutMutationAttemptState.ready.rawValue
            attemptCount = 0
        }
    }

    @Model
    final class LoadoutConflict {
        #Unique<LoadoutConflict>([\.loadoutID])
        #Index<LoadoutConflict>([\.scopeID], [\.detectedAt])

        var id: UUID
        var scopeID: UUID
        var loadoutID: UUID
        var baseRevision: Int64?
        var localSnapshotData: Data
        var remoteSnapshotData: Data?
        var remoteRevision: Int64
        var remoteCreatedAt: Date?
        var remoteChangedAt: Date
        var isRemoteTombstone: Bool
        var detectedAt: Date

        init(
            id: UUID = UUID(),
            scopeID: UUID,
            loadoutID: UUID,
            baseRevision: Int64?,
            localSnapshotData: Data,
            remoteSnapshotData: Data?,
            remoteRevision: Int64,
            remoteCreatedAt: Date?,
            remoteChangedAt: Date,
            isRemoteTombstone: Bool,
            detectedAt: Date
        ) {
            self.id = id
            self.scopeID = scopeID
            self.loadoutID = loadoutID
            self.baseRevision = baseRevision
            self.localSnapshotData = localSnapshotData
            self.remoteSnapshotData = remoteSnapshotData
            self.remoteRevision = remoteRevision
            self.remoteCreatedAt = remoteCreatedAt
            self.remoteChangedAt = remoteChangedAt
            self.isRemoteTombstone = isRemoteTombstone
            self.detectedAt = detectedAt
        }
    }
}
