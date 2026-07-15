//
//  LoadoutPreviewDefinition.swift
//  BagLog
//
//  Created by Eugene on 15.07.2026.
//  https://github.com/kovs705
//

import Foundation

#if DEBUG

struct LoadoutPreviewDefinition {
    let title: String
    let summary: String
    let category: LoadoutCategory
    let visibility: LoadoutVisibility
    let status: LoadoutStatus
    let itemTitles: [String]

    func makeLoadout(ownerID: UUID) -> Loadout {
        let loadout = Loadout(
            ownerID: ownerID,
            title: title,
            summary: summary,
            category: category,
            visibility: visibility,
            status: status
        )
        loadout.items = itemTitles.enumerated().map { index, title in
            LoadoutItem(title: title, sortIndex: index)
        }
        return loadout
    }
}

#endif
