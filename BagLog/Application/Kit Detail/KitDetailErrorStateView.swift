//
//  KitDetailErrorStateView.swift
//  BagLog
//
//  Create by Eugene Kovs on 15.07.2026.
//  https://github.com/kovs705
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
