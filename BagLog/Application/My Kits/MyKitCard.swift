import Persistence
import SwiftUI

struct MyKitCard: View {
    let loadout: LoadoutSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MyKitCover(loadout: loadout)

            VStack(alignment: .leading, spacing: 12) {
                Text(loadout.title)
                    .font(.title3)
                    .fontDesign(.serif)
                    .bold()
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                if !loadout.summary.isEmpty {
                    Text(loadout.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }

                MyKitCardMetadata(loadout: loadout)
            }
            .padding(MyKitsDesign.cardContentPadding)
        }
        .background(.background, in: .rect(cornerRadius: MyKitsDesign.cardCornerRadius))
        .clipShape(.rect(cornerRadius: MyKitsDesign.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: MyKitsDesign.cardCornerRadius)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: MyKitsDesign.cardCornerRadius))
        .accessibilityElement(children: .combine)
    }
}
