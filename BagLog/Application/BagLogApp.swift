//
//  BagLogAppApp.swift
//  BagLog
//
//  Created by Eugene Kovs on 09.07.2026.
//  https://github.com/kovs705
//

import Persistence
import SwiftData
import SwiftUI

@main
@MainActor
struct BagLogApp: App {

    @Environment(\.scenePhase) private var scenePhase
    @State private var router = Router()
    @State private var authenticationStore: AuthenticationStore
    @State private var loadoutSyncCoordinator: LoadoutSyncCoordinator
    private let modelContainer: ModelContainer
    private let persistence: any BagLogSyncPersisting
    private let mediaStore: any MediaStoring

    init() {
        let authenticationStore = AuthenticationComposition.make()
        _authenticationStore = State(initialValue: authenticationStore)
        do {
            let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            let modelContainer = try BagLogModelContainer.make(
                isStoredInMemoryOnly: isUITesting
            )
            self.modelContainer = modelContainer
            let persistence = SwiftDataPersistence(modelContainer: modelContainer)
            self.persistence = persistence
            if isUITesting {
                mediaStore = try FileMediaStore(
                    applicationSupportDirectory: FileManager.default.temporaryDirectory
                        .appendingPathComponent("BagLogUITests", isDirectory: true)
                )
            } else {
                mediaStore = try FileMediaStore()
            }
            let syncConfiguration = LoadoutSyncConfiguration()
            let authenticationConfiguration = AuthenticationConfiguration()
            _loadoutSyncCoordinator = State(
                initialValue: LoadoutSyncComposition.make(
                    configuration: syncConfiguration,
                    apiBaseURL: authenticationConfiguration.apiBaseURL,
                    sessionController: authenticationStore.sessionController,
                    persistence: persistence
                )
            )
        } catch {
            fatalError("BagLog could not initialize its local data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(router)
                .environment(authenticationStore)
                .environment(loadoutSyncCoordinator)
                .environment(\.bagLogPersistence, persistence)
                .environment(\.bagLogMediaStore, mediaStore)
                .environment(\.loadoutSyncTrigger, loadoutSyncCoordinator.trigger)
                .environment(\.loadoutSyncRetry, loadoutSyncCoordinator.retry)
                .environment(
                    \.loadoutSyncDataRevision,
                    loadoutSyncCoordinator.dataRevision
                )
                .modelContainer(modelContainer)
                .task {
                    await authenticationStore.restore()
                }
                .onOpenURL { url in
                    authenticationStore.handle(url)
                }
                .task(
                    id: LoadoutSyncActivation(
                        authenticationState: authenticationStore.state,
                        scenePhase: scenePhase,
                        triggerRevision: loadoutSyncCoordinator.triggerRevision
                    )
                ) {
                    await loadoutSyncCoordinator.synchronize(
                        isAuthenticated: authenticationStore.state == .signedIn,
                        isForeground: scenePhase == .active
                    )
                }
        }
    }
}

private struct LoadoutSyncActivation: Equatable {
    let authenticationState: AuthenticationState
    let scenePhase: ScenePhase
    let triggerRevision: Int
}
