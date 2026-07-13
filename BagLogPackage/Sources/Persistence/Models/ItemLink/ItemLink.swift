//
//  ItemLink.swift
//  BagLog
//
//  Created by Eugene Kovs on 12.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

@available(iOS 18.0, macOS 15.0, *)
@Model
public final class ItemLink {
    public var id: UUID
    public var urlString: String
    public var label: String?
    public var sortIndex: Int
    public var item: LoadoutItem?

    public init(
        id: UUID = UUID(),
        urlString: String,
        label: String? = nil,
        sortIndex: Int
    ) {
        self.id = id
        self.urlString = urlString
        self.label = label
        self.sortIndex = sortIndex
    }
}
