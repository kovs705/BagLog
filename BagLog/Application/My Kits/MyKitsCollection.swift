import DesignSystem
import Persistence
import SwiftUI

struct MyKitsCollection: View {
    let loadouts: [LoadoutSnapshot]
    let scope: MyKitsScope
    let columnCount: Int
    let openDraft: (UUID) -> Void

    var body: some View {
        if loadouts.isEmpty {
            ContentUnavailableView(
                scope.emptyTitle,
                systemImage: scope.emptySymbol,
                description: Text(scope.emptyDescription)
            )
            .frame(maxWidth: .infinity)
            .padding(.top, MyKitsDesign.sectionSpacing)
        } else {
            MasonryLayout(columns: columnCount, spacing: MyKitsDesign.gridSpacing) {
                ForEach(loadouts) { loadout in
                    MyKitLibraryDestination(
                        loadout: loadout,
                        openDraft: openDraft
                    )
                }
            }
        }
    }
}
