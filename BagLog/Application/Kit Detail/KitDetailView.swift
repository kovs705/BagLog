//
//  KitDetailView.swift
//  BagLog
//
//  Created by Eugene on 15.07.2026.
//  https://github.com/kovs705
//

import Persistence
import SwiftData
import SwiftUI

struct KitDetailView: View {
    let loadoutID: UUID

    @Environment(\.bagLogPersistence) private var persistence
    @State private var store = KitDetailStore()

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading kit")
            } else if store.hasLoadingError {
                KitDetailErrorStateView(retry: reload)
            } else if let loadout = store.loadout {
                KitDetailContentView(loadout: loadout)
            } else {
                ContentUnavailableView(
                    "Kit unavailable",
                    systemImage: "backpack",
                    description: Text("This kit may have been deleted.")
                )
            }
        }
        .navigationTitle(store.loadout?.title ?? "Kit")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: loadoutID) {
            await store.load(id: loadoutID, using: persistence)
        }
    }

    private func reload() {
        Task {
            await store.load(id: loadoutID, using: persistence)
        }
    }
}

#if DEBUG
#Preview("Kit detail") {
    let modelContainer = BagLogPreviewData.makeModelContainer()
    let modelContext = ModelContext(modelContainer)
    let descriptor = FetchDescriptor<Loadout>()
    let loadoutID = (try? modelContext.fetch(descriptor).first?.id) ?? UUID()

    NavigationStack {
        KitDetailView(loadoutID: loadoutID)
    }
    .environment(\.bagLogPersistence, SwiftDataPersistence(modelContainer: modelContainer))
    .modelContainer(modelContainer)
}
#endif
