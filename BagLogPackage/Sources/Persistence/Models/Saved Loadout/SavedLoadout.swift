//
//  SavedLoadout.swift
//  BagLog
//
//  Created by Eugene Kovs on 12.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

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
