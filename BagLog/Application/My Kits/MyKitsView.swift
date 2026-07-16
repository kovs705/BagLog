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
        @Bindable var router = router

        NavigationStack(path: $router.myKitsPath) {
            Group {
                if store.isLoading {
                    ProgressView("Loading your kits")
                } else if store.hasLoadingError {
                    MyKitsErrorStateView(retry: reload)
                } else if store.loadouts.isEmpty {
                    MyKitsEmptyStateView(createKit: presentCreateKit)
                } else {
                    List(store.loadouts) { loadout in
                        if loadout.status == .draft {
                            Button {
                                router.presentEditor(loadoutID: loadout.id)
                            } label: {
                                MyKitRow(loadout: loadout)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens this draft for editing")
                            .accessibilityIdentifier("edit-draft-\(loadout.id.uuidString)")
                        } else {
                            NavigationLink(value: MyKitsRoute.detail(loadout.id)) {
                                MyKitRow(loadout: loadout)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Kits")
            .navigationDestination(for: MyKitsRoute.self) { route in
                switch route {
                case let .detail(loadoutID):
                    KitDetailView(loadoutID: loadoutID)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create kit", systemImage: "plus", action: presentCreateKit)
                }
            }
            .task(id: router.kitsRevision) {
                await store.load(using: persistence)
            }
        }
    }

    private func presentCreateKit() {
        router.presentNewKit()
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
