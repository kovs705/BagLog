import ImageIO
import SwiftUI

struct BagLogThumbnailImage: View {
    let data: Data
    let accessibilityLabel: String

    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                ContentUnavailableView(
                    "Photo unavailable",
                    systemImage: "photo"
                )
            }
        }
        .task(id: data) {
            image = makeImage()
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private func makeImage() -> Image? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        return Image(decorative: cgImage, scale: 1)
    }
}
