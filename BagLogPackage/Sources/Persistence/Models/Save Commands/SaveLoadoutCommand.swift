//
//  SaveLoadoutCommand.swift
//  BagLog
//
//  Created by Eugene Kovs on 12.07.2026.
//  https://github.com/kovs705
//

import Foundation

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
