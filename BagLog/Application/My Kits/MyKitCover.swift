import Foundation
import Persistence
import SwiftUI

struct MyKitCover: View {
    let loadout: LoadoutSnapshot

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let coverData = loadout.myKitsCoverThumbnailData {
                    BagLogThumbnailImage(
                        data: coverData,
                        accessibilityLabel: "Cover photo for \(loadout.title)"
                    )
                } else {
                    MyKitCoverFallback(loadout: loadout)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: coverHeight)
            .clipped()

            MyKitStatusBadge(status: loadout.status)
                .padding(12)
        }
    }

    private var coverHeight: CGFloat {
        loadout.status == .published
            ? MyKitsDesign.featuredCoverHeight
            : MyKitsDesign.standardCoverHeight
    }
}
