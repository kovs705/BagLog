//
//  MyKitsErrorStateView.swift
//  BagLog
//
//  Created by Eugene on 15.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct MyKitsErrorStateView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Unable to load kits", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Try loading your local kits again.")
        } actions: {
            Button("Try again", systemImage: "arrow.clockwise", action: retry)
        }
    }
}
