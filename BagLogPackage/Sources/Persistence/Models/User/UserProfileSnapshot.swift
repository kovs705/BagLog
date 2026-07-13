//
//  UserProfileSnapshot.swift
//  BagLog
//
//  Created by Eugene Kovs on 11.07.2026.
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
