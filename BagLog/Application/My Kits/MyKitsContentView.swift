import DesignSystem
import Persistence
import SwiftUI

struct MyKitsContentView: View {
    @Bindable var store: MyKitsStore
    @Binding var scope: MyKitsScope
    let createKit: () -> Void
    let openDraft: (UUID) -> Void
    let persistence: (any BagLogPersisting)?

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading your kits")
            } else if store.hasLoadingError {
                MyKitsErrorStateView(retry: retryLoading)
            } else if store.loadouts.isEmpty {
                MyKitsEmptyStateView(createKit: createKit)
            } else {
                MyKitsLibraryView(
                    store: store,
                    scope: $scope,
                    createKit: createKit,
                    openDraft: openDraft,
                    persistence: persistence
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .supportNeutralGradientBackground()
    }

    private func retryLoading() {
        Task {
            await store.load(using: persistence)
        }
    }
}
