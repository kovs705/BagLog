//
//  CreateKitPhaseView.swift
//  BagLog
//
//  Created by Eugene Kovs on 25.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct CreateKitPhaseView: View {
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding
    let reduceMotion: Bool
    let accessibilityTitle: String
    let topics: [CreateKitTopic]
    let retryStart: () -> Void

    var body: some View {
        switch store.phase {
        case .loading:
            CreateKitLoadingView()
        case .needsProfile:
            CreateKitProfileGateView(store: store, focus: focus)
        case .editing:
            if let draft = Binding($store.draft) {
                CreateKitEditorView(
                    draft: draft,
                    store: store,
                    focus: focus,
                    reduceMotion: reduceMotion,
                    accessibilityTitle: accessibilityTitle,
                    topics: topics
                )
                .ignoresSafeArea(edges: .top)
            } else {
                CreateKitErrorView(
                    message: "The draft is unavailable.",
                    retry: retryStart
                )
            }
        case .failed:
            CreateKitErrorView(
                message: store.message ?? "BagLog couldn’t open this editor.",
                retry: retryStart
            )
        }
    }
}
