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
struct BagLogApp: App {

    @State private var router = Router()
    private let modelContainer: ModelContainer
    private let persistence: any BagLogPersisting

    init() {
        do {
            let modelContainer = try BagLogModelContainer.make()
            self.modelContainer = modelContainer
            persistence = SwiftDataPersistence(modelContainer: modelContainer)
        } catch {
            fatalError("BagLog could not initialize its local data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(router)
                .environment(\.bagLogPersistence, persistence)
                .modelContainer(modelContainer)
        }
    }
}
