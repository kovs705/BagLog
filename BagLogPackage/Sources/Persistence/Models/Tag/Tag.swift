//
//  Tag.swift
//  BagLog
//
//  Created by Eugene Kovs on 12.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

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
