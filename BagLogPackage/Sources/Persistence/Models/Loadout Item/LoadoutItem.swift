//
//  LoadoutItem.swift
//  BagLog
//
//  Created by Eugene Kovs on 11.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

@available(iOS 18.0, macOS 15.0, *)
@Model
public final class LoadoutItem {
    #Index<LoadoutItem>([\.sortIndex])

    public var id: UUID
    public var title: String
    public var brand: String?
    public var model: String?
    public var notes: String?
    public var quantity: Int
    public var sortIndex: Int
    public var isEssential: Bool
    public var loadout: Loadout?

    @Relationship(deleteRule: .cascade, inverse: \ItemLink.item)
    public var links: [ItemLink] = []

    public init(
        id: UUID = UUID(),
        title: String,
        brand: String? = nil,
        model: String? = nil,
        notes: String? = nil,
        quantity: Int = 1,
        sortIndex: Int,
        isEssential: Bool = false
    ) {
        self.id = id
        self.title = title
        self.brand = brand
        self.model = model
        self.notes = notes
        self.quantity = quantity
        self.sortIndex = sortIndex
        self.isEssential = isEssential
    }
}
