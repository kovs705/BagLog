//
//  SwiftDataPersistence+Profiles.swift
//  BagLog
//
//  Created by Eugene Kovs on 10.07.2026.
//  https://github.com/kovs705
//

import Foundation

@available(iOS 18.0, macOS 15.0, *)
extension SwiftDataPersistence {
    func validatedProfileValues(from command: SaveUserProfileCommand) throws -> (handle: String, displayName: String, bio: String?) {
        let handle = command.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = command.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !handle.isEmpty else { throw PersistenceError.invalidHandle }
        guard !displayName.isEmpty else { throw PersistenceError.invalidDisplayName }
        return (handle.lowercased(), displayName, normalizedOptionalText(command.bio))
    }

    func profileToSave(
        for command: SaveUserProfileCommand,
        values: (handle: String, displayName: String, bio: String?),
        now: Date
    ) throws -> UserProfile {
        guard let id = command.id else {
            let profile = UserProfile(handle: values.handle, displayName: values.displayName, bio: values.bio, avatarAssetID: command.avatarAssetID, createdAt: now, updatedAt: now)
            modelContext.insert(profile)
            return profile
        }
        let profile = try requiredProfile(id: id)
        profile.handle = values.handle
        profile.displayName = values.displayName
        profile.bio = values.bio
        profile.avatarAssetID = command.avatarAssetID
        profile.updatedAt = now
        return profile
    }
}
