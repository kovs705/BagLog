//
//  ForkOriginSnapshot.swift
//  BagLog
//
//  Created by Eugene Kovs on 12.07.2026.
//  https://github.com/kovs705
//

import Foundation

public struct ForkOriginSnapshot: Sendable, Equatable {
    public let sourceLoadoutID: UUID
    public let sourceRemoteID: String?
    public let rootLoadoutID: UUID
    public let sourceTitle: String
    public let sourceAuthorHandle: String
    public let forkedAt: Date
    
    public init(
        sourceLoadoutID: UUID,
        sourceRemoteID: String?,
        rootLoadoutID: UUID,
        sourceTitle: String,
        sourceAuthorHandle: String,
        forkedAt: Date
    ) {
        self.sourceLoadoutID = sourceLoadoutID
        self.sourceRemoteID = sourceRemoteID
        self.rootLoadoutID = rootLoadoutID
        self.sourceTitle = sourceTitle
        self.sourceAuthorHandle = sourceAuthorHandle
        self.forkedAt = forkedAt
    }
}
