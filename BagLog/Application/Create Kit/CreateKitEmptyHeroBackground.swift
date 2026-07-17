import SwiftUI

struct CreateKitEmptyHeroBackground: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.5, 0.5), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: [
                Color(red: 0.08, green: 0.07, blue: 0.06),
                Color(red: 0.17, green: 0.12, blue: 0.08),
                Color(red: 0.07, green: 0.07, blue: 0.06),
                Color(red: 0.19, green: 0.10, blue: 0.05),
                Color(red: 0.11, green: 0.10, blue: 0.08),
                Color(red: 0.26, green: 0.13, blue: 0.05),
                Color(red: 0.07, green: 0.07, blue: 0.06),
                Color(red: 0.13, green: 0.09, blue: 0.06),
                Color(red: 0.06, green: 0.06, blue: 0.05)
            ],
            background: .black,
            smoothsColors: true
        )
        .overlay {
            Image(systemName: "backpack.fill")
                .font(.largeTitle.scaled(by: 3.2))
                .foregroundStyle(.white.opacity(0.06))
                .accessibilityHidden(true)
        }
    }
}
