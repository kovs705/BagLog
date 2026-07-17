import Persistence
import SwiftUI

struct MyKitLibraryDestination: View {
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
        } else {
            NavigationLink(value: MyKitsRoute.detail(loadout.id)) {
                MyKitCard(loadout: loadout)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens kit details")
            .accessibilityIdentifier("open-kit-\(loadout.id.uuidString)")
        }
    }

    private func presentDraft() {
        openDraft(loadout.id)
    }
}
