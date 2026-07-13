//
//  ForkLoadoutCommand.swift
//  BagLog
//
//  Created by Eugene Kovs on 12.07.2026.
//  https://github.com/kovs705
//

import Foundation

public struct ForkLoadoutCommand: Sendable, Equatable {
    public let sourceLoadoutID: UUID
    public let ownerID: UUID
    public let title: String?

    public init(sourceLoadoutID: UUID, ownerID: UUID, title: String? = nil) {
        self.sourceLoadoutID = sourceLoadoutID
        self.ownerID = ownerID
        self.title = title
    }
}
