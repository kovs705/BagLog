import SwiftUI

struct CreateKitHeroBackground: View {
    let coverPhoto: CreateKitPhotoDraft?

    var body: some View {
        Group {
            if let coverPhoto {
                BagLogThumbnailImage(
                    data: coverPhoto.thumbnailData,
                    accessibilityLabel: "Kit cover photo"
                )
            } else {
                CreateKitEmptyHeroBackground()
            }
        }
        .overlay {
            LinearGradient(
                colors: [
                    .black.opacity(0.62),
                    .black.opacity(0.3),
                    .black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
