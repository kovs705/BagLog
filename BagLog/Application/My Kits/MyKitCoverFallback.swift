import Persistence
import SwiftUI

struct MyKitCoverFallback: View {
    let loadout: LoadoutSnapshot

    var body: some View {
        ZStack {
            Color.orange.opacity(0.1)

            VStack(spacing: 12) {
                Image(systemName: loadout.myKitsCategorySymbol)
                    .font(.largeTitle.scaled(by: 1.35))
                    .foregroundStyle(.orange)

                Text(loadout.title.prefix(1).uppercased())
                    .font(.title2)
                    .fontDesign(.serif)
                    .bold()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
    }
}
