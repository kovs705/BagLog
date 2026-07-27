import Persistence
import SwiftUI

struct LoadoutSyncStatusBadge: View {
    let state: LoadoutSyncState

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(style)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: .capsule)
            .accessibilityLabel("Sync status: \(accessibilityTitle)")
    }

    private var title: String {
        switch state {
        case .local:
            "On this device"
        case .pendingUpload, .waiting:
            "Waiting to sync"
        case .synced:
            "Synced"
        case .failed:
            "Sync needs attention"
        case .conflicted:
            "Choose a version"
        }
    }

    private var accessibilityTitle: String {
        switch state {
        case .local:
            "Saved on this device"
        case .pendingUpload, .waiting:
            "Saved on this device and waiting to sync"
        case .synced:
            "Saved on this device and synced"
        case .failed:
            "Saved on this device; synchronization needs attention"
        case .conflicted:
            "Saved on this device; choose between device and server versions"
        }
    }

    private var symbol: String {
        switch state {
        case .local:
            "iphone"
        case .pendingUpload, .waiting:
            "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .synced:
            "checkmark.icloud"
        case .failed:
            "exclamationmark.icloud"
        case .conflicted:
            "arrow.trianglehead.branch"
        }
    }

    private var style: AnyShapeStyle {
        switch state {
        case .failed, .conflicted:
            AnyShapeStyle(.orange)
        default:
            AnyShapeStyle(.secondary)
        }
    }
}
