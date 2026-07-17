import SwiftUI

struct CreateKitPhotoCard: View {
    let photo: CreateKitPhotoDraft
    let position: Int
    let isCover: Bool
    let isFirst: Bool
    let isLast: Bool
    @Bindable var store: CreateKitStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDropTarget = false

    var body: some View {
        BagLogThumbnailImage(
            data: photo.thumbnailData,
            accessibilityLabel: isCover ? "Kit cover photo" : "Kit photo"
        )
        .frame(
            width: CreateKitDesign.heroPhotoWidth,
            height: CreateKitDesign.heroPhotoHeight
        )
        .clipShape(.rect(cornerRadius: CreateKitDesign.compactCornerRadius))
        .overlay(alignment: .topLeading) {
            Text(position, format: .number)
                .font(.subheadline)
                .bold()
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(isCover ? Color.orange : Color.black.opacity(0.58), in: .circle)
                .padding(8)
                .accessibilityHidden(true)
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
            .buttonBorderShape(.circle)
            .labelStyle(.iconOnly)
            .tint(.white)
            .padding(8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CreateKitDesign.compactCornerRadius)
                .stroke(isCover ? Color.orange : .white.opacity(0.24), lineWidth: isCover ? 2 : 1)
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
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .snappy, value: isDropTarget)
        .accessibilityAction(named: "Move earlier", moveEarlier)
        .accessibilityAction(named: "Move later", moveLater)
        .accessibilityHint(isCover ? "Current cover photo" : "Photo \(position)")
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
