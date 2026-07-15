//
//  MyKitsView.swift
//  BagLog
//
//  Created by Eugene on 13.07.2026.
//  https://github.com/kovs705
//

import Persistence
import SwiftUI

struct MyKitsView: View {
    @Environment(Router.self) private var router
    @Environment(\.bagLogPersistence) private var persistence
    @State private var store = MyKitsStore()

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView("Loading your kits")
                } else if store.hasLoadingError {
                    MyKitsErrorStateView(retry: reload)
                } else if store.loadouts.isEmpty {
                    MyKitsEmptyStateView(createKit: presentCreateKit)
                } else {
                    List(store.loadouts) { loadout in
                        NavigationLink(value: loadout.id) {
                            MyKitRow(loadout: loadout)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Kits")
            .navigationDestination(for: UUID.self) { loadoutID in
                KitDetailView(loadoutID: loadoutID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create kit", systemImage: "plus", action: presentCreateKit)
                }
            }
            .task {
                await store.load(using: persistence)
            }
        }
    }

    private func presentCreateKit() {
        router.createKitIsPresented = true
    }

    private func reload() {
        Task {
            await store.load(using: persistence)
        }
    }
}

#if DEBUG
#Preview("My kits") {
    let modelContainer = BagLogPreviewData.makeModelContainer()

    MyKitsView()
        .environment(Router())
        .environment(\.bagLogPersistence, SwiftDataPersistence(modelContainer: modelContainer))
        .modelContainer(modelContainer)
}
#endif
