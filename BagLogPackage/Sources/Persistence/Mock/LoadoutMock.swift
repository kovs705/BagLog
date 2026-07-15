//
//  LoadoutMock.swift
//  BagLog
//
//  Created by Eugene on 15.07.2026.
//  https://github.com/kovs705
//

import Foundation

#if DEBUG

public extension Loadout {
    @MainActor static func previewSamples(ownerID: UUID) -> [Loadout] {
        previewDefinitions.map { $0.makeLoadout(ownerID: ownerID) }
    }

    private static let previewDefinitions: [LoadoutPreviewDefinition] = [
        .init(
            title: "Everyday work bag",
            summary: "A focused setup for a day at the studio.",
            category: .work,
            visibility: .private,
            status: .draft,
            itemTitles: ["MacBook Air", "Notebook", "USB-C charger"]
        ),
        .init(
            title: "One-bag weekend",
            summary: "Everything needed for a short city break.",
            category: .travel,
            visibility: .public,
            status: .published,
            itemTitles: ["Packing cubes", "Water bottle", "Passport", "Power bank"]
        ),
        .init(
            title: "Camera walk",
            summary: "A compact kit for street photography.",
            category: .camera,
            visibility: .private,
            status: .draft,
            itemTitles: ["Camera", "35 mm lens", "Spare battery"]
        )
    ]
}

#endif
