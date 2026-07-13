//
//  ItemLinkSnapshot.swift
//  BagLog
//
//  Created by Eugene Kovs on 12.07.2026.
//  https://github.com/kovs705
//

import Foundation

public struct ItemLinkSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let urlString: String
    public let label: String?
    public let sortIndex: Int

    public init(id: UUID, urlString: String, label: String?, sortIndex: Int) {
        self.id = id
        self.urlString = urlString
        self.label = label
        self.sortIndex = sortIndex
    }
}
