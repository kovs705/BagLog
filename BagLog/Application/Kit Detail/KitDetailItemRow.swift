//
//  KitDetailItemRow.swift
//  BagLog
//
//  Create by Eugene Kovs on 15.07.2026.
//  https://github.com/kovs705
//

import Persistence
import SwiftUI

struct KitDetailItemRow: View {
    let item: LoadoutItemSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.headline)

            if let category = item.category, !category.isEmpty {
                Label(category, systemImage: "square.grid.2x2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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

            ForEach(item.links) { link in
                if let destination = link.destination {
                    Link(destination: destination) {
                        Label(link.displayLabel, systemImage: "link")
                    }
                    .accessibilityHint("Opens in your browser")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: item.links.isEmpty ? .combine : .contain)
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

private extension ItemLinkSnapshot {
    var destination: URL? {
        guard let url = URL(string: urlString),
              url.scheme?.lowercased() == "https",
              url.host() != nil else { return nil }
        return url
    }

    var displayLabel: String {
        guard let label, !label.isEmpty else { return "Open link" }
        return label
    }
}
