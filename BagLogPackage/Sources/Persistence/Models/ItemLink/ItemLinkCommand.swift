//
//  ItemLinkCommand.swift
//  BagLog
//
//  Created by Eugene Kovs on 12.07.2026.
//  https://github.com/kovs705
//

import Foundation

public struct ItemLinkCommand: Sendable, Equatable {
    public let id: UUID?
    public let urlString: String
    public let label: String?

    public init(id: UUID? = nil, urlString: String, label: String? = nil) {
        self.id = id
        self.urlString = urlString
        self.label = label
    }
}
