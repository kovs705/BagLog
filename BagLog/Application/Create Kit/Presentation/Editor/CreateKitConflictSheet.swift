import Persistence
import SwiftUI

struct CreateKitConflictSheet: View {
    @Environment(\.dismiss) private var dismiss

    let conflict: LoadoutConflictSnapshot
    let resolve: (LoadoutConflictResolution) async -> Void

    @State private var isResolving = false

    var body: some View {
        NavigationStack {
            List {
                Section("This Device") {
                    localVersion
                }

                Section(remoteSectionTitle) {
                    remoteVersion
                }

                Section {
                    resolutionActions
                } footer: {
                    Text("BagLog never picks a version by timestamp.")
                }
            }
            .navigationTitle("Resolve Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now", action: dismiss.callAsFunction)
                        .disabled(isResolving)
                }
            }
            .disabled(isResolving)
            .overlay {
                if isResolving {
                    ProgressView("Applying your choice")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 16))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var localVersion: some View {
        if conflict.localOperation == .delete {
            Label("Deleted on this device", systemImage: "trash")
        } else {
            versionRow(
                title: conflict.localSnapshot.title,
                itemCount: conflict.localSnapshot.items.count,
                symbol: "iphone"
            )
        }
    }

    @ViewBuilder
    private var remoteVersion: some View {
        switch conflict.remoteVersion {
        case let .aggregate(aggregate):
            versionRow(
                title: aggregate.projection.title,
                itemCount: aggregate.projection.items.count,
                symbol: "server.rack"
            )
        case .tombstone:
            Label {
                Text("This draft was deleted on the server.")
            } icon: {
                Image(systemName: "trash")
            }
        }
    }

    @ViewBuilder
    private var resolutionActions: some View {
        switch conflict.remoteVersion {
        case .aggregate:
            if conflict.localOperation == .delete {
                Button(
                    "Delete Server Version",
                    systemImage: "trash",
                    role: .destructive
                ) {
                    perform(.useThisDevice)
                }
                Button("Keep Server Version", systemImage: "server.rack") {
                    perform(.useServerVersion)
                }
            } else {
                Button("Use This Device", systemImage: "iphone") {
                    perform(.useThisDevice)
                }
                Button("Use Server Version", systemImage: "server.rack") {
                    perform(.useServerVersion)
                }
            }
        case .tombstone:
            Button("Save as New Draft", systemImage: "doc.badge.plus") {
                perform(.saveAsNewDraft)
            }
            Button(
                "Accept Deletion",
                systemImage: "trash",
                role: .destructive
            ) {
                perform(.acceptDeletion)
            }
        }
    }

    private var remoteSectionTitle: String {
        switch conflict.remoteVersion {
        case .aggregate:
            "Server Version"
        case .tombstone:
            "Server"
        }
    }

    private func versionRow(
        title: String,
        itemCount: Int,
        symbol: String
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(itemCount == 1 ? "1 item" : "\(itemCount) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
        }
    }

    private func perform(_ resolution: LoadoutConflictResolution) {
        isResolving = true
        Task {
            await resolve(resolution)
            isResolving = false
            dismiss()
        }
    }
}
