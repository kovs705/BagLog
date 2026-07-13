//
//  Loadout.swift
//  BagLog
//
//  Created by Eugene Kovs on 11.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

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
