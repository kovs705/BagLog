//
//  MyKitRow.swift
//  BagLog
//
//  Created by Eugene on 15.07.2026.
//  https://github.com/kovs705
//

import Persistence
import SwiftUI

struct MyKitRow: View {
    let loadout: LoadoutSnapshot

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline) {
                Label(loadout.myKitsCategoryTitle, systemImage: loadout.myKitsCategorySymbol)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Label(loadout.myKitsStatusTitle, systemImage: loadout.myKitsStatusSymbol)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(loadout.title)
                .font(.headline)

            if !loadout.summary.isEmpty {
                Text(loadout.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Label(loadout.myKitsItemCountTitle, systemImage: "shippingbox")
                Spacer()
                Text(loadout.updatedAt, format: .dateTime.month(.abbreviated).day().year())
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical)
        .accessibilityElement(children: .combine)
    }
}
