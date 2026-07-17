import Persistence
import SwiftUI

struct CreateKitView: View {
    let presentation: CreateKitPresentation
    let topics: [CreateKitTopic]

    @Environment(Router.self) private var router
    @Environment(\.bagLogPersistence) private var persistence
    @Environment(\.bagLogMediaStore) private var mediaStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = CreateKitStore()
    @FocusState private var focusedField: CreateKitFocusField?

    init(
        presentation: CreateKitPresentation,
        topics: [CreateKitTopic] = CreateKitTopic.bundled
    ) {
        self.presentation = presentation
        self.topics = topics
    }

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            content
                .navigationTitle(store.phase == .editing ? "" : presentation.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(store.phase == .editing ? .hidden : .automatic, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close", systemImage: "xmark", action: close)
                            .labelStyle(.titleAndIcon)
                            .accessibilityIdentifier("close-kit-editor")
                            .disabled(store.isPublishing)
                    }

                    if store.phase == .editing {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Publish") {
                                store.requestPublish()
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.orange)
                            .disabled(!store.canPublish)
                            .accessibilityIdentifier("publish-kit")
                        }
                    }

                    CreateKitKeyboardToolbar(
                        store: store,
                        focus: $focusedField
                    )
                }
        }
        .task {
            await start()
        }
        .onChange(of: store.phase, focusFirstField)
        .interactiveDismissDisabled(store.requiresDismissProtection)
        .confirmationDialog(
            "Unsaved changes",
            isPresented: $store.isShowingCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Keep Editing", role: .cancel) {}
            Button("Retry Saving", action: retryClose)
            Button("Discard Unsaved Changes", role: .destructive, action: discardAndClose)
        } message: {
            Text(store.message ?? "Save this kit before closing, or discard only the changes that aren’t saved yet.")
        }
        .confirmationDialog(
            "Publish this kit?",
            isPresented: $store.isShowingPublishConfirmation,
            titleVisibility: .visible
        ) {
            Button("Publish on This Device", action: publish)
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Publishing makes this kit read-only in BagLog. It stays local to this device.")
        }
        .presentationSizing(.page)
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            CreateKitLoadingView()
        case .needsProfile:
            CreateKitProfileGateView(store: store, focus: $focusedField)
        case .editing:
            CreateKitEditorView(
                store: store,
                focus: $focusedField,
                reduceMotion: reduceMotion,
                accessibilityTitle: presentation.navigationTitle,
                topics: topics
            )
            .ignoresSafeArea(edges: .top)
        case .failed:
            CreateKitErrorView(
                message: store.message ?? "BagLog couldn’t open this editor.",
                retry: retryStart
            )
        }
    }

    private func start() async {
        guard let persistence, let mediaStore else {
            store.reportMissingDependencies()
            return
        }

        await store.start(
            presentation: presentation,
            dependencies: CreateKitDependencies(
                persistence: persistence,
                mediaStore: mediaStore
            )
        )
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
                // The store exposes an actionable, user-facing message inline.
            }
        }
    }

    private func retryStart() {
        Task {
            await store.retryStart()
        }
    }
}

private extension CreateKitPresentation {
    var navigationTitle: String {
        switch self {
        case .new: "New kit"
        case .edit: "Edit kit"
        }
    }
}
