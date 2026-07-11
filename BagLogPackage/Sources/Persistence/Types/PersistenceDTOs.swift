//
//  PersistenceDTOs.swift
//  BagLog
//
//  Created by Eugene Kovs on 10.07.2026.
//  https://github.com/kovs705
//

import Foundation

public struct UserProfileSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let handle: String
    public let displayName: String
    public let bio: String?
    public let avatarAssetID: UUID?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        handle: String,
        displayName: String,
        bio: String?,
        avatarAssetID: UUID?,
        createdAt: Date,
        updatedAt: Date
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

public struct ItemLinkSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let urlString: String
    public let label: String?
    public let sortIndex: Int

    public init(id: UUID, urlString: String, label: String?, sortIndex: Int) {
        self.id = id
        self.urlString = urlString
        self.label = label
        self.sortIndex = sortIndex
    }
}

public struct LoadoutItemSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let brand: String?
    public let model: String?
    public let notes: String?
    public let quantity: Int
    public let sortIndex: Int
    public let isEssential: Bool
    public let links: [ItemLinkSnapshot]

    public init(
        id: UUID,
        title: String,
        brand: String?,
        model: String?,
        notes: String?,
        quantity: Int,
        sortIndex: Int,
        isEssential: Bool,
        links: [ItemLinkSnapshot]
    ) {
        self.id = id
        self.title = title
        self.brand = brand
        self.model = model
        self.notes = notes
        self.quantity = quantity
        self.sortIndex = sortIndex
        self.isEssential = isEssential
        self.links = links
    }
}

public struct LoadoutAssetSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let mediaKind: LoadoutMediaKind
    public let sortIndex: Int
    public let caption: String?
    public let localFileName: String?
    public let remoteURLString: String?
    public let thumbnailData: Data?

    public init(
        id: UUID,
        mediaKind: LoadoutMediaKind,
        sortIndex: Int,
        caption: String?,
        localFileName: String?,
        remoteURLString: String?,
        thumbnailData: Data?
    ) {
        self.id = id
        self.mediaKind = mediaKind
        self.sortIndex = sortIndex
        self.caption = caption
        self.localFileName = localFileName
        self.remoteURLString = remoteURLString
        self.thumbnailData = thumbnailData
    }
}

public struct ForkOriginSnapshot: Sendable, Equatable {
    public let sourceLoadoutID: UUID
    public let sourceRemoteID: String?
    public let rootLoadoutID: UUID
    public let sourceTitle: String
    public let sourceAuthorHandle: String
    public let forkedAt: Date

    public init(
        sourceLoadoutID: UUID,
        sourceRemoteID: String?,
        rootLoadoutID: UUID,
        sourceTitle: String,
        sourceAuthorHandle: String,
        forkedAt: Date
    ) {
        self.sourceLoadoutID = sourceLoadoutID
        self.sourceRemoteID = sourceRemoteID
        self.rootLoadoutID = rootLoadoutID
        self.sourceTitle = sourceTitle
        self.sourceAuthorHandle = sourceAuthorHandle
        self.forkedAt = forkedAt
    }
}

public struct LoadoutSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let ownerID: UUID
    public let remoteID: String?
    public let title: String
    public let summary: String
    public let category: LoadoutCategory
    public let visibility: LoadoutVisibility
    public let status: LoadoutStatus
    public let syncState: LoadoutSyncState
    public let createdAt: Date
    public let updatedAt: Date
    public let publishedAt: Date?
    public let archivedAt: Date?
    public let lastSyncedAt: Date?
    public let remoteRevision: String?
    public let tagNames: [String]
    public let items: [LoadoutItemSnapshot]
    public let assets: [LoadoutAssetSnapshot]
    public let forkOrigin: ForkOriginSnapshot?

    public init(
        id: UUID,
        ownerID: UUID,
        remoteID: String?,
        title: String,
        summary: String,
        category: LoadoutCategory,
        visibility: LoadoutVisibility,
        status: LoadoutStatus,
        syncState: LoadoutSyncState,
        createdAt: Date,
        updatedAt: Date,
        publishedAt: Date?,
        archivedAt: Date?,
        lastSyncedAt: Date?,
        remoteRevision: String?,
        tagNames: [String],
        items: [LoadoutItemSnapshot],
        assets: [LoadoutAssetSnapshot],
        forkOrigin: ForkOriginSnapshot?
    ) {
        self.id = id
        self.ownerID = ownerID
        self.remoteID = remoteID
        self.title = title
        self.summary = summary
        self.category = category
        self.visibility = visibility
        self.status = status
        self.syncState = syncState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.publishedAt = publishedAt
        self.archivedAt = archivedAt
        self.lastSyncedAt = lastSyncedAt
        self.remoteRevision = remoteRevision
        self.tagNames = tagNames
        self.items = items
        self.assets = assets
        self.forkOrigin = forkOrigin
    }
}

public struct SaveUserProfileCommand: Sendable, Equatable {
    public let id: UUID?
    public let handle: String
    public let displayName: String
    public let bio: String?
    public let avatarAssetID: UUID?

    public init(
        id: UUID? = nil,
        handle: String,
        displayName: String,
        bio: String? = nil,
        avatarAssetID: UUID? = nil
    ) {
        self.id = id
        self.handle = handle
        self.displayName = displayName
        self.bio = bio
        self.avatarAssetID = avatarAssetID
    }
}

public struct ItemLinkCommand: Sendable, Equatable {
    public let id: UUID?
    public let urlString: String
    public let label: String?

    public init(id: UUID? = nil, urlString: String, label: String? = nil) {
        self.id = id
        self.urlString = urlString
        self.label = label
    }
}

public struct LoadoutItemCommand: Sendable, Equatable {
    public let id: UUID?
    public let title: String
    public let brand: String?
    public let model: String?
    public let notes: String?
    public let quantity: Int
    public let isEssential: Bool
    public let links: [ItemLinkCommand]

    public init(
        id: UUID? = nil,
        title: String,
        brand: String? = nil,
        model: String? = nil,
        notes: String? = nil,
        quantity: Int = 1,
        isEssential: Bool = false,
        links: [ItemLinkCommand] = []
    ) {
        self.id = id
        self.title = title
        self.brand = brand
        self.model = model
        self.notes = notes
        self.quantity = quantity
        self.isEssential = isEssential
        self.links = links
    }
}

public struct LoadoutAssetCommand: Sendable, Equatable {
    public let id: UUID?
    public let mediaKind: LoadoutMediaKind
    public let caption: String?
    public let localFileName: String?
    public let remoteURLString: String?
    public let thumbnailData: Data?

    public init(
        id: UUID? = nil,
        mediaKind: LoadoutMediaKind,
        caption: String? = nil,
        localFileName: String? = nil,
        remoteURLString: String? = nil,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.mediaKind = mediaKind
        self.caption = caption
        self.localFileName = localFileName
        self.remoteURLString = remoteURLString
        self.thumbnailData = thumbnailData
    }
}

public struct SaveLoadoutCommand: Sendable, Equatable {
    public let id: UUID?
    public let ownerID: UUID
    public let title: String
    public let summary: String
    public let category: LoadoutCategory
    public let visibility: LoadoutVisibility
    public let status: LoadoutStatus
    public let tagNames: [String]
    public let items: [LoadoutItemCommand]
    public let assets: [LoadoutAssetCommand]

    public init(
        id: UUID? = nil,
        ownerID: UUID,
        title: String,
        summary: String = "",
        category: LoadoutCategory = .other,
        visibility: LoadoutVisibility = .private,
        status: LoadoutStatus = .draft,
        tagNames: [String] = [],
        items: [LoadoutItemCommand] = [],
        assets: [LoadoutAssetCommand] = []
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.summary = summary
        self.category = category
        self.visibility = visibility
        self.status = status
        self.tagNames = tagNames
        self.items = items
        self.assets = assets
    }
}

public struct ForkLoadoutCommand: Sendable, Equatable {
    public let sourceLoadoutID: UUID
    public let ownerID: UUID
    public let title: String?

    public init(sourceLoadoutID: UUID, ownerID: UUID, title: String? = nil) {
        self.sourceLoadoutID = sourceLoadoutID
        self.ownerID = ownerID
        self.title = title
    }
}
