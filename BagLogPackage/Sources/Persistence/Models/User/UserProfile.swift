//
//  UserProfile.swift
//  BagLog
//
//  Created by Eugene Kovs on 11.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

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
