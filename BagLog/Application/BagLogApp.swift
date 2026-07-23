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

    @State private var router = Router()
    @State private var authenticationStore: AuthenticationStore
    private let modelContainer: ModelContainer
    private let persistence: any BagLogPersisting
    private let mediaStore: any MediaStoring

    init() {
        _authenticationStore = State(initialValue: AuthenticationComposition.make())
        do {
            let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            let modelContainer = try BagLogModelContainer.make(
                isStoredInMemoryOnly: isUITesting
            )
            self.modelContainer = modelContainer
            persistence = SwiftDataPersistence(modelContainer: modelContainer)
            if isUITesting {
                mediaStore = try FileMediaStore(
                    applicationSupportDirectory: FileManager.default.temporaryDirectory
                        .appendingPathComponent("BagLogUITests", isDirectory: true)
                )
            } else {
                mediaStore = try FileMediaStore()
            }
        } catch {
            fatalError("BagLog could not initialize its local data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(router)
                .environment(authenticationStore)
                .environment(\.bagLogPersistence, persistence)
                .environment(\.bagLogMediaStore, mediaStore)
                .modelContainer(modelContainer)
                .task {
                    await authenticationStore.restore()
                }
                .onOpenURL { url in
                    authenticationStore.handle(url)
                }
        }
    }
}
