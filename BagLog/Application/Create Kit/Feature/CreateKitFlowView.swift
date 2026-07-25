//
//  CreateKitFlowView.swift
//  BagLog
//
//  Created by Eugene Kovs on 25.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct CreateKitFlowView: View {
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let presentation: CreateKitPresentation
    let topics: [CreateKitTopic]

    @State private var store: CreateKitStore
    @FocusState private var focusedField: CreateKitFocusField?

    init(
        presentation: CreateKitPresentation,
        topics: [CreateKitTopic],
        dependencies: CreateKitDependencies
    ) {
        self.presentation = presentation
        self.topics = topics
        _store = State(
            initialValue: CreateKitStore(
                presentation: presentation,
                dependencies: dependencies
            )
        )
    }

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            CreateKitPhaseView(
                store: store,
                focus: $focusedField,
                reduceMotion: reduceMotion,
                accessibilityTitle: presentation.createKitNavigationTitle,
                topics: topics,
                retryStart: retryStart
            )
            .navigationTitle(
                store.phase == .editing ? "" : presentation.createKitNavigationTitle
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                store.phase == .editing ? .hidden : .automatic,
                for: .navigationBar
            )
            .toolbar {
                CreateKitNavigationToolbar(
                    store: store,
                    close: close,
                    retryClose: retryClose,
                    discardAndClose: discardAndClose,
                    publish: publish
                )

                CreateKitKeyboardToolbar(
                    store: store,
                    focus: $focusedField
                )
            }
        }
        .task {
            await store.start()
        }
        .onChange(of: store.phase, focusFirstField)
        .interactiveDismissDisabled(store.requiresDismissProtection)
    }

    private func focusFirstField(
        _ oldPhase: CreateKitPhase,
        _ newPhase: CreateKitPhase
    ) {
        guard oldPhase != newPhase else { return }

        switch newPhase {
        case .needsProfile:
            focusedField = .profileDisplayName
        case .editing:
            focusedField = .title
        case .loading, .failed:
            focusedField = nil
        }
    }

    private func close() {
        Task {
            if await store.prepareToClose() == .dismiss {
                router.dismissEditor()
            }
        }
    }

    private func retryClose() {
        Task {
            if await store.retryCloseSave() == .dismiss {
                router.dismissEditor()
            }
        }
    }

    private func discardAndClose() {
        Task {
            await store.discardUnsavedChanges()
            router.dismissEditor()
        }
    }

    private func publish() {
        Task {
            do {
                let loadoutID = try await store.publish()
                router.finishPublishing(loadoutID: loadoutID)
            } catch {
                store.reportPublishFailure(error)
            }
        }
    }

    private func retryStart() {
        Task {
            await store.retryStart()
        }
    }
}
