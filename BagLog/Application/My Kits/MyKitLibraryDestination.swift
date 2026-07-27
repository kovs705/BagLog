import Persistence
import SwiftUI

struct MyKitLibraryDestination: View {
    @Environment(\.loadoutSyncRetry) private var retrySync

    let loadout: LoadoutSnapshot
    let openDraft: (UUID) -> Void

    var body: some View {
        if loadout.status == .draft {
            Button(action: presentDraft) {
                MyKitCard(loadout: loadout)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens this draft for editing")
            .accessibilityIdentifier("edit-draft-\(loadout.id.uuidString)")
            .modifier(SyncRetryActions(loadout: loadout, retry: retrySync))
        } else {
            NavigationLink(value: MyKitsRoute.detail(loadout.id)) {
                MyKitCard(loadout: loadout)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens kit details")
            .accessibilityIdentifier("open-kit-\(loadout.id.uuidString)")
            .modifier(SyncRetryActions(loadout: loadout, retry: retrySync))
        }
    }

    private func presentDraft() {
        openDraft(loadout.id)
    }
}

private struct SyncRetryActions: ViewModifier {
    let loadout: LoadoutSnapshot
    let retry: (@MainActor () -> Void)?

    func body(content: Content) -> some View {
        if loadout.syncState == .failed, let retry {
            content
                .contextMenu {
                    Button("Retry Sync", systemImage: "arrow.clockwise", action: retry)
                }
                .accessibilityAction(named: "Retry sync", retry)
        } else {
            content
        }
    }
}
