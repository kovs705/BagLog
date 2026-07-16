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
            if !galleryAssets.isEmpty {
                Section("Gallery") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(galleryAssets.enumerated(), id: \.element.id) { index, asset in
                                BagLogThumbnailImage(
                                    data: asset.thumbnailData ?? Data(),
                                    accessibilityLabel: index == 0 ? "Kit cover photo" : "Kit photo \(index + 1)"
                                )
                                .frame(width: 240, height: 180)
                                .clipShape(.rect(cornerRadius: 16))
                                .overlay(alignment: .topLeading) {
                                    if index == 0 {
                                        Label("Cover", systemImage: "star.fill")
                                            .font(.subheadline)
                                            .padding(8)
                                            .background(.regularMaterial, in: .capsule)
                                            .padding(8)
                                    }
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .listRowInsets(EdgeInsets())
                }
            }

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

    private var galleryAssets: [LoadoutAssetSnapshot] {
        loadout.assets.filter {
            $0.mediaKind == .image && $0.thumbnailData?.isEmpty == false
        }
    }
}
