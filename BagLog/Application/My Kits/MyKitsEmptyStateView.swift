//
//  MyKitsEmptyStateView.swift
//  BagLog
//
//  Created by Eugene on 15.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct MyKitsEmptyStateView: View {
    let createKit: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No kits yet", systemImage: "duffle.bag")
        } description: {
            Text("Create a kit for the things you carry, pack, or use together.")
        } actions: {
            Button("Create kit", systemImage: "plus", action: createKit)
        }
    }
}
