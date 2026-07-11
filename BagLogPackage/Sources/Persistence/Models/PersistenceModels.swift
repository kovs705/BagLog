//
//  PersistenceModels.swift
//  BagLog
//
//  Created by Eugene Kovs on 10.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

public enum LoadoutCategory: String, CaseIterable, Codable, Sendable {
    case everydayCarry
    case travel
    case cycling
    case camera
    case work
    case outdoor
    case emergency
    case fitness
    case parenting
    case other
}

public enum LoadoutVisibility: String, Codable, Sendable {
    case `private`
    case `public`
}

public enum LoadoutStatus: String, Codable, Sendable {
    case draft
    case published
    case archived
}

public enum LoadoutSyncState: String, Codable, Sendable {
    case local
    case pendingUpload
    case synced
    case failed
}

public enum LoadoutMediaKind: String, Codable, Sendable {
    case image
    case video
}

@available(iOS 18.0, macOS 15.0, *)
@Model
public final class UserProfile {
    #Index<UserProfile>([\.handle])

    public var id: UUID
    public var handle: String
    public var displayName: String
    public var bio: String?
    public var avatarAssetID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Loadout.owner)
    public var loadouts: [Loadout] = []

    public init(
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

@available(iOS 18.0, macOS 15.0, *)
@Model
public final class Loadout {
    #Index<Loadout>(
        [\.updatedAt],
        [\.statusRaw],
        [\.visibilityRaw],
        [\.categoryRaw],
        [\.ownerID]
    )

    public var id: UUID
    public var ownerID: UUID
    public var remoteID: String?
    public var title: String
    public var summary: String
    public var categoryRaw: String
    public var visibilityRaw: String
    public var statusRaw: String
    public var syncStateRaw: String
    public var createdAt: Date
    public var updatedAt: Date
    public var publishedAt: Date?
    public var archivedAt: Date?
    public var lastSyncedAt: Date?
    public var remoteRevision: String?

    public var owner: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \LoadoutItem.loadout)
    public var items: [LoadoutItem] = []

    @Relationship(deleteRule: .cascade, inverse: \LoadoutAsset.loadout)
    public var assets: [LoadoutAsset] = []

    @Relationship(deleteRule: .cascade, inverse: \ForkOrigin.loadout)
    public var forkOrigin: ForkOrigin?

    @Relationship(deleteRule: .nullify, inverse: \Tag.loadouts)
    public var tags: [Tag] = []

    public var category: LoadoutCategory {
        get { LoadoutCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    public var visibility: LoadoutVisibility {
        get { LoadoutVisibility(rawValue: visibilityRaw) ?? .private }
        set { visibilityRaw = newValue.rawValue }
    }

    public var status: LoadoutStatus {
        get { LoadoutStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    public var syncState: LoadoutSyncState {
        get { LoadoutSyncState(rawValue: syncStateRaw) ?? .local }
        set { syncStateRaw = newValue.rawValue }
    }

    public init(
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

@available(iOS 18.0, macOS 15.0, *)
@Model
public final class LoadoutItem {
    #Index<LoadoutItem>([\.sortIndex])

    public var id: UUID
    public var title: String
    public var brand: String?
    public var model: String?
    public var notes: String?
    public var quantity: Int
    public var sortIndex: Int
    public var isEssential: Bool
    public var loadout: Loadout?

    @Relationship(deleteRule: .cascade, inverse: \ItemLink.item)
    public var links: [ItemLink] = []

    public init(
        id: UUID = UUID(),
        title: String,
        brand: String? = nil,
        model: String? = nil,
        notes: String? = nil,
        quantity: Int = 1,
        sortIndex: Int,
        isEssential: Bool = false
    ) {
        self.id = id
        self.title = title
        self.brand = brand
        self.model = model
        self.notes = notes
        self.quantity = quantity
        self.sortIndex = sortIndex
        self.isEssential = isEssential
    }
}

@available(iOS 18.0, macOS 15.0, *)
@Model
public final class ItemLink {
    public var id: UUID
    public var urlString: String
    public var label: String?
    public var sortIndex: Int
    public var item: LoadoutItem?

    public init(
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

@available(iOS 18.0, macOS 15.0, *)
@Model
public final class LoadoutAsset {
    public var id: UUID
    public var mediaKindRaw: String
    public var sortIndex: Int
    public var caption: String?
    public var localFileName: String?
    public var remoteURLString: String?

    @Attribute(.externalStorage)
    public var thumbnailData: Data?

    public var loadout: Loadout?

    public var mediaKind: LoadoutMediaKind {
        get { LoadoutMediaKind(rawValue: mediaKindRaw) ?? .image }
        set { mediaKindRaw = newValue.rawValue }
    }

    public init(
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

@available(iOS 18.0, macOS 15.0, *)
@Model
public final class Tag {
    #Index<Tag>([\.normalizedName])

    public var id: UUID
    public var name: String
    public var normalizedName: String
    public var createdAt: Date
    public var updatedAt: Date
    public var loadouts: [Loadout] = []

    public init(
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

@available(iOS 18.0, macOS 15.0, *)
@Model
public final class ForkOrigin {
    public var sourceLoadoutID: UUID
    public var sourceRemoteID: String?
    public var rootLoadoutID: UUID
    public var sourceTitle: String
    public var sourceAuthorHandle: String
    public var forkedAt: Date
    public var loadout: Loadout?

    public init(
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

@available(iOS 18.0, macOS 15.0, *)
@Model
public final class SavedLoadout {
    #Index<SavedLoadout>([\.profileID], [\.loadoutID])

    public var id: UUID
    public var profileID: UUID
    public var loadoutID: UUID
    public var savedAt: Date

    public init(
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
