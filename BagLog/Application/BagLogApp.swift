//
//  BagLogAppApp.swift
//  BagLog
//
//  Created by Eugene Kovs on 09.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

@main
struct BagLogApp: App {
    
    @State private var router = Router()
    @State private var appState = BagLogAppState()

    var body: some Scene {
        WindowGroup {
            BagLogRootView()
                .environment(appState)
                .environment(router)
        }
    }
}
