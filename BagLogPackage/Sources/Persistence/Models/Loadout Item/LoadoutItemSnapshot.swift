//
//  LoadoutItemSnapshot.swift
//  BagLog
//
//  Created by Eugene Kovs on 11.07.2026.
//  https://github.com/kovs705
//

import Foundation

public struct LoadoutItemSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let category: String?
    public let brand: String?
    public let model: String?
    public let notes: String?
    public let quantity: Int
    public let sortIndex: Int
    public let isEssential: Bool
    public let links: [ItemLinkSnapshot]

    public init(
        id: UUID,
        title: String,
        category: String?,
        brand: String?,
        model: String?,
        notes: String?,
        quantity: Int,
        sortIndex: Int,
        isEssential: Bool,
        links: [ItemLinkSnapshot]
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.brand = brand
        self.model = model
        self.notes = notes
        self.quantity = quantity
        self.sortIndex = sortIndex
        self.isEssential = isEssential
        self.links = links
    }
}
