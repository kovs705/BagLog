//
//  SaveUserProfileCommand.swift
//  BagLog
//
//  Created by Eugene Kovs on 11.07.2026.
//  https://github.com/kovs705
//

import Foundation

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
