import Persistence
import SwiftUI

struct MyKitsLibraryView: View {
    @Bindable var store: MyKitsStore
    @Binding var scope: MyKitsScope
    let createKit: () -> Void
    let openDraft: (UUID) -> Void
    let persistence: (any BagLogPersisting)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MyKitsDesign.sectionSpacing) {
                MyKitsLibraryHeader(
                    scope: $scope,
                    createKit: createKit
                )

                MyKitsCollection(
                    loadouts: visibleLoadouts,
                    scope: scope,
                    columnCount: columnCount,
                    openDraft: openDraft
                )
            }
            .padding(.horizontal, MyKitsDesign.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, MyKitsDesign.sectionSpacing)
            .containerRelativeFrame(.horizontal) { length, _ in
                min(length, 820)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await store.load(using: persistence)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var visibleLoadouts: [LoadoutSnapshot] {
        store.loadouts.filter { scope.includes($0.status) }
    }

    private var columnCount: Int {
        if dynamicTypeSize.isAccessibilitySize {
            1
        } else if horizontalSizeClass == .regular {
            3
        } else {
            2
        }
    }
}
