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
    @Environment(\.loadoutSyncDataRevision) private var syncDataRevision

    @State private var store = MyKitsStore()
    @State private var scope = MyKitsScope.all

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.myKitsPath) {
            MyKitsContentView(
                store: store,
                scope: $scope,
                createKit: presentCreateKit,
                openDraft: presentDraft,
                persistence: persistence
            )
            .navigationTitle("")
            .navigationDestination(for: MyKitsRoute.self) { route in
                switch route {
                case let .detail(loadoutID):
                    KitDetailView(loadoutID: loadoutID)
                }
            }
            .task(
                id: MyKitsLoadRevision(
                    routerRevision: router.kitsRevision,
                    syncRevision: syncDataRevision
                )
            ) {
                await store.load(using: persistence)
            }
        }
    }

    private func presentCreateKit() {
        router.presentNewKit()
    }

    private func presentDraft(_ loadoutID: UUID) {
        router.presentEditor(loadoutID: loadoutID)
    }

}

private struct MyKitsLoadRevision: Equatable {
    let routerRevision: Int
    let syncRevision: Int
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
