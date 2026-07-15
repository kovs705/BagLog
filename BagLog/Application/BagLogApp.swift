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

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(router)
        }
    }
}
