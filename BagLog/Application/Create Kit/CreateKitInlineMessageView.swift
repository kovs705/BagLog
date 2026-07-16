import SwiftUI

struct CreateKitInlineMessageView: View {
    let message: String
    let retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if let retry {
                Button("Retry", action: retry)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.orange.tertiary, in: .rect(cornerRadius: CreateKitDesign.compactCornerRadius))
        .accessibilityElement(children: .combine)
    }
}
