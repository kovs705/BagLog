import Foundation
import SwiftData

extension BagLogSchemaV1 {
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
}
