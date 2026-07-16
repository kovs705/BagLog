import SwiftUI

struct CreateKitPhotoCard: View {
    let photo: CreateKitPhotoDraft
    let isCover: Bool
    let isFirst: Bool
    let isLast: Bool
    @Bindable var store: CreateKitStore
    @State private var isDropTarget = false

    var body: some View {
        BagLogThumbnailImage(
            data: photo.thumbnailData,
            accessibilityLabel: isCover ? "Kit cover photo" : "Kit photo"
        )
        .frame(width: 248, height: CreateKitDesign.galleryHeight)
        .clipShape(.rect(cornerRadius: CreateKitDesign.compactCornerRadius))
        .overlay(alignment: .topLeading) {
            if isCover {
                Label("Cover", systemImage: "star.fill")
                    .font(.subheadline)
                    .padding(8)
                    .background(.regularMaterial, in: .capsule)
                    .padding(8)
            }
        }
        .overlay(alignment: .topTrailing) {
            Menu("Photo actions", systemImage: "ellipsis") {
                if !isCover {
                    Button("Make cover", systemImage: "star", action: makeCover)
                }

                Button("Move earlier", systemImage: "arrow.left", action: moveEarlier)
                    .disabled(isFirst)
                Button("Move later", systemImage: "arrow.right", action: moveLater)
                    .disabled(isLast)

                Button("Remove", systemImage: "trash", role: .destructive, action: remove)
            }
            .buttonStyle(.bordered)
            .padding(8)
        }
        .draggable(CreateKitPhotoOrderTransfer(id: photo.id))
        .dropDestination(for: CreateKitPhotoOrderTransfer.self, action: handleDrop)
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: CreateKitDesign.compactCornerRadius)
                    .stroke(
                        Color.orange,
                        style: StrokeStyle(lineWidth: 3, dash: [8, 5])
                    )
            }
        }
        .animation(.snappy, value: isDropTarget)
        .accessibilityAction(named: "Move earlier", moveEarlier)
        .accessibilityAction(named: "Move later", moveLater)
    }

    private func makeCover() {
        store.makeCover(photoID: photo.id)
    }

    private func remove() {
        Task {
            await store.removePhoto(id: photo.id)
        }
    }

    private func moveEarlier() {
        store.movePhotoEarlier(id: photo.id)
    }

    private func moveLater() {
        store.movePhotoLater(id: photo.id)
    }

    private func handleDrop(
        _ transfers: [CreateKitPhotoOrderTransfer],
        _ session: DropSession
    ) {
        switch session.phase {
        case .entering, .active:
            isDropTarget = true
            guard let transfer = transfers.first else { return }
            store.movePhoto(id: transfer.id, before: photo.id)
        case .exiting, .ended, .dataTransferCompleted:
            isDropTarget = false
        @unknown default:
            isDropTarget = false
        }
    }
}
