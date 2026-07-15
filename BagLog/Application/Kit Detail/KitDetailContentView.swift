//
//  KitDetailContentView.swift
//  BagLog
//
//  Create by Eugene Kovs on 15.07.2026.
//  https://github.com/kovs705
//

import Persistence
import SwiftUI

struct KitDetailContentView: View {
    let loadout: LoadoutSnapshot

    var body: some View {
        List {
            Section("Details") {
                Label(loadout.myKitsCategoryTitle, systemImage: loadout.myKitsCategorySymbol)
                Label(loadout.myKitsStatusTitle, systemImage: loadout.myKitsStatusSymbol)
                Label(loadout.kitDetailVisibilityTitle, systemImage: loadout.kitDetailVisibilitySymbol)
            }

            if !loadout.summary.isEmpty {
                Section("About") {
                    Text(loadout.summary)
                }
            }

            if !loadout.tagNames.isEmpty {
                Section("Tags") {
                    ForEach(loadout.tagNames, id: \.self) { tagName in
                        Text(tagName)
                    }
                }
            }

            Section("Items") {
                if loadout.items.isEmpty {
                    ContentUnavailableView(
                        "No items yet",
                        systemImage: "shippingbox",
                        description: Text("Add items to make this kit useful.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(loadout.items) { item in
                        KitDetailItemRow(item: item)
                    }
                }
            }

            Section("Activity") {
                LabeledContent("Created") {
                    Text(loadout.createdAt, format: .dateTime.month(.abbreviated).day().year())
                }

                LabeledContent("Updated") {
                    Text(loadout.updatedAt, format: .dateTime.month(.abbreviated).day().year())
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
