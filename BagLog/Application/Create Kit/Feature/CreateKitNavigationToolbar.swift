//
//  CreateKitNavigationToolbar.swift
//  BagLog
//
//  Created by Eugene Kovs on 25.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct CreateKitNavigationToolbar: ToolbarContent {
    @Bindable var store: CreateKitStore
    let close: () -> Void
    let retryClose: () -> Void
    let discardAndClose: () -> Void
    let publish: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Close", systemImage: "xmark", action: close)
                .labelStyle(.titleAndIcon)
                .accessibilityIdentifier("close-kit-editor")
                .disabled(store.isPublishing)
                .confirmationDialog(
                    "Unsaved changes",
                    isPresented: $store.isShowingCloseConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Keep Editing", role: .cancel) {}
                    Button("Retry Saving", action: retryClose)
                    Button(
                        "Discard Unsaved Changes",
                        role: .destructive,
                        action: discardAndClose
                    )
                } message: {
                    Text(
                        store.message
                            ?? "Save this kit before closing, or discard only the changes that aren’t saved yet."
                    )
                }
        }

        if store.phase == .editing {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Publish", action: store.requestPublish)
                    .buttonStyle(.glassProminent)
                    .tint(.orange)
                    .disabled(!store.canPublish)
                    .accessibilityIdentifier("publish-kit")
                    .confirmationDialog(
                        "Publish this kit?",
                        isPresented: $store.isShowingPublishConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Publish on This Device", action: publish)
                        Button("Keep Editing", role: .cancel) {}
                    } message: {
                        Text(
                            "Publishing makes this kit read-only in BagLog. It stays local to this device."
                        )
                    }
            }
        }
    }
}
