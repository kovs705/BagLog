//
//  KitDetailErrorStateView.swift
//  BagLog
//
//  Created by Codex on 15.07.2026.
//

import SwiftUI

struct KitDetailErrorStateView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't load kit", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Please try again.")
        } actions: {
            Button("Try again", action: retry)
        }
    }
}
