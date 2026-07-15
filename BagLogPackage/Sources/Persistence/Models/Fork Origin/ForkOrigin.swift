//
//  ForkOrigin.swift
//  BagLog
//
//  Created by Eugene Kovs on 12.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

@Model
public final class ForkOrigin {
    public var sourceLoadoutID: UUID
    public var sourceRemoteID: String?
    public var rootLoadoutID: UUID
    public var sourceTitle: String
    public var sourceAuthorHandle: String
    public var forkedAt: Date
    public var loadout: Loadout?

    public init(
        sourceLoadoutID: UUID,
        sourceRemoteID: String?,
        rootLoadoutID: UUID,
        sourceTitle: String,
        sourceAuthorHandle: String,
        forkedAt: Date = .now
    ) {
        self.sourceLoadoutID = sourceLoadoutID
        self.sourceRemoteID = sourceRemoteID
        self.rootLoadoutID = rootLoadoutID
        self.sourceTitle = sourceTitle
        self.sourceAuthorHandle = sourceAuthorHandle
        self.forkedAt = forkedAt
    }
}
