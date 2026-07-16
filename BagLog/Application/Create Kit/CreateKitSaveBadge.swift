import SwiftUI

struct CreateKitSaveBadge: View {
    let state: CreateKitSaveState
    let label: String

    var body: some View {
        Label(label, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(state == .failed ? .red : .secondary)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityLabel("Draft status: \(label)")
    }

    private var symbol: String {
        switch state {
        case .idle: "pencil"
        case .saving: "arrow.trianglehead.2.clockwise.rotate.90"
        case .saved: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        }
    }
}
