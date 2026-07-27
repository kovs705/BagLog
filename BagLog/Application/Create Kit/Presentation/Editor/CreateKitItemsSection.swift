//
//  CreateKitItemsSection.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct CreateKitItemsSection: View {
    @Binding var items: [CreateKitItemDraft]
    @Bindable var store: CreateKitStore
    let parentFocus: FocusState<CreateKitFocusField?>.Binding
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CreateKitDesign.cardSpacing) {
            HStack {
                Label("Items", systemImage: "shippingbox")
                    .font(.title2)
                    .bold()

                Spacer()

                Text("^[\(items.count) item](inflect: true)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                ContentUnavailableView {
                    Label("Add your first item", systemImage: "shippingbox")
                } description: {
                    Text("Use the composer below and press Return to add it.")
                }
                .frame(maxWidth: .infinity)
            } else {
                ForEach($items) { $item in
                    CreateKitItemCard(
                        item: $item,
                        position: itemPosition(item.id),
                        itemCount: items.count,
                        store: store,
                        parentFocus: parentFocus,
                        reduceMotion: reduceMotion
                    )
                    .id(item.id)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
                }
            }
        }
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .snappy,
            value: items.map(\.id)
        )
    }

    private func itemPosition(_ id: UUID) -> Int {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return 1 }
        return index + 1
    }
}
