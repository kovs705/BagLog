//
//  LoadoutSnapshot.swift
//  BagLog
//
//  Created by Eugene Kovs on 11.07.2026.
//  https://github.com/kovs705
//

import Foundation

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
