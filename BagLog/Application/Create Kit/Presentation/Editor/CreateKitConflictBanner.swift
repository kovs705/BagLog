import SwiftUI

struct CreateKitConflictBanner: View {
    let review: () -> Void

    var body: some View {
        Button(action: review) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.trianglehead.branch")
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 3) {
                    Text("This draft changed elsewhere")
                        .font(.headline)
                    Text("Both versions are safe. Review them before syncing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.leading)
            .padding()
            .background(.orange.opacity(0.12), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens version comparison and resolution actions")
    }
}
