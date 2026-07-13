//
//  LoadoutItemCommand.swift
//  BagLog
//
//  Created by Eugene Kovs on 11.07.2026.
//  https://github.com/kovs705
//

import Foundation

public struct LoadoutItemCommand: Sendable, Equatable {
    public let id: UUID?
    public let title: String
    public let brand: String?
    public let model: String?
    public let notes: String?
    public let quantity: Int
    public let isEssential: Bool
    public let links: [ItemLinkCommand]

    public init(
        id: UUID? = nil,
        title: String,
        brand: String? = nil,
        model: String? = nil,
        notes: String? = nil,
        quantity: Int = 1,
        isEssential: Bool = false,
        links: [ItemLinkCommand] = []
    ) {
        self.id = id
        self.title = title
        self.brand = brand
        self.model = model
        self.notes = notes
        self.quantity = quantity
        self.isEssential = isEssential
        self.links = links
    }
}
