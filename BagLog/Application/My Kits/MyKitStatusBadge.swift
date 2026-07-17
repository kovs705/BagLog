import Persistence
import SwiftUI

struct MyKitStatusBadge: View {
    let status: LoadoutStatus

    var body: some View {
        Label(statusTitle, systemImage: statusSymbol)
            .font(.subheadline)
            .foregroundStyle(status == .published ? .orange : .secondary)
            .padding(.horizontal, 10)
            .frame(minHeight: 36)
            .background(.regularMaterial, in: .capsule)
    }

    private var statusTitle: String {
        switch status {
        case .draft: "Draft"
        case .published: "Published"
        case .archived: "Archived"
        }
    }

    private var statusSymbol: String {
        switch status {
        case .draft: "circle.fill"
        case .published: "checkmark.seal.fill"
        case .archived: "archivebox.fill"
        }
    }
}
