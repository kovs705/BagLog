//
//  KitDetailItemRow.swift
//  BagLog
//
//  Created by Codex on 15.07.2026.
//

import Persistence
import SwiftUI

struct KitDetailItemRow: View {
    let item: LoadoutItemSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.headline)

            if let brandAndModel {
                Text(brandAndModel)
                    .foregroundStyle(.secondary)
            }

            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Quantity: \(item.quantity)")

                if item.isEssential {
                    Label("Essential", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var brandAndModel: String? {
        let values = [item.brand, item.model].compactMap { value -> String? in
            guard let value, !value.isEmpty else {
                return nil
            }
            return value
        }

        return values.isEmpty ? nil : values.joined(separator: " · ")
    }
}
