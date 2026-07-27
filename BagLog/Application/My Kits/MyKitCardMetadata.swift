import Persistence
import SwiftUI

struct MyKitCardMetadata: View {
    let loadout: LoadoutSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(loadout.myKitsItemCountTitle, systemImage: "shippingbox")

            Divider()

            Label(loadout.myKitsCategoryTitle, systemImage: loadout.myKitsCategorySymbol)
                .lineLimit(1)

            Label {
                Text(
                    loadout.updatedAt,
                    format: .dateTime.day().month(.abbreviated).year()
                )
            } icon: {
                Image(systemName: "calendar")
            }

            if loadout.syncState != .local {
                LoadoutSyncStatusBadge(state: loadout.syncState)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}
